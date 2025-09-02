import logger from "./utils/logger.js";
import { ConfigManager } from "./utils/config.js";
import { MCPConnection } from "./MCPConnection.js";
import {
  ServerError,
  ConnectionError,
  ConfigError,
  wrapError,
} from "./utils/errors.js";
import EventEmitter from "events";

export class MCPHub extends EventEmitter {
  constructor(configPathOrObject, { port, watch = false, marketplace } = {}) {
    super();
    this.connections = new Map();
    this.port = port;
    this.hubServerUrl = `http://localhost:${port}`;
    this.configManager = new ConfigManager(configPathOrObject);
    this.shouldWatchConfig = watch && (typeof configPathOrObject === "string" || Array.isArray(configPathOrObject));
    this.marketplace = marketplace;
  }
  async initialize(isRestarting) {
    try {
      await this.configManager.loadConfig();

      if (this.shouldWatchConfig && !isRestarting) {
        this.configManager.watchConfig();
        this.configManager.on("configChanged", async ({ config, changes }) => {
          await this.handleConfigUpdated(config, changes);
        });
      }

      await this.startConfiguredServers();
    } catch (error) {
      // Only wrap if it's not already our error type
      if (!(error instanceof ConfigError)) {
        throw wrapError(error, "HUB_INIT_ERROR", {
          watchEnabled: this.shouldWatchConfig,
        });
      }
      throw error;
    }
  }

  async startConfiguredServers() {
    const config = this.configManager.getConfig();
    const servers = Object.entries(config?.mcpServers || {});
    await this.disconnectAll();

    logger.info(
      `Starting ${servers.length} configured MCP servers in parallel`,
      {
        count: servers.length,
      }
    );
    // Create and connect servers in parallel
    const startPromises = servers.map(async ([name, serverConfig]) => {
      try {
        if (serverConfig.disabled === true) {
          logger.debug(`Skipping disabled MCP server '${name}'`, {
            server: name,
          });
        } else {
          logger.info(`Initializing MCP server '${name}'`, { server: name });
        }

        const connection = new MCPConnection(
          name,
          serverConfig,
          this.marketplace,
          this.hubServerUrl,
        );
        ["toolsChanged", "resourcesChanged", "promptsChanged", "notification"].forEach((event) => {
          connection.on(event, (data) => {
            this.emit(event, data);
          });
        });

        // Setup dev event handlers
        connection.on("devServerRestarting", (data) => {
          this.emit("devServerRestarting", data);
        });
        connection.on("devServerRestarted", (data) => {
          this.emit("devServerRestarted", data);
        });

        this.connections.set(name, connection);
        await connection.connect();

        return {
          name,
          status: "success",
          config: serverConfig,
        };
      } catch (error) {
        const e = wrapError(error);
        logger.error(e.code || "SERVER_START_ERROR", e.message, e.data, false);

        return {
          name,
          status: "error",
          error: error.message,
          config: serverConfig,
        };
      }
    });

    // Wait for all servers to start and log summary
    const results = await Promise.all(startPromises);

    const successful = results.filter((r) => r.status === "success");
    const failed = results.filter((r) => r.status === "error");
    const disabled = results.filter((r) => r.config.disabled === true);

    logger.info(`${successful.length}/${servers.length} servers started successfully`, {
      total: servers.length,
      successful: successful.length,
      failed: failed.length,
      disabled: disabled.length,
      failedServers: failed.map((f) => f.name),
    });
  }

  async startServer(name) {
    const config = this.configManager.getConfig();
    const serverConfig = config.mcpServers?.[name];
    if (!serverConfig) {
      throw new ServerError("Server not found", { server: name });
    }

    const connection = this.connections.get(name);
    if (!connection) {
      throw new ServerError("Server connection not found", { server: name });
    }

    // If server was disabled, update config
    if (serverConfig.disabled) {
      serverConfig.disabled = false;
      await this.configManager.updateConfig(config);
    }
    connection.config = serverConfig
    return await connection.start();
  }

  async stopServer(name, disable = false) {
    const config = this.configManager.getConfig();
    const serverConfig = config.mcpServers?.[name];
    if (!serverConfig) {
      throw new ServerError("Server not found", { server: name });
    }

    // If disabling, update config
    if (disable) {
      serverConfig.disabled = true;
      await this.configManager.updateConfig(config);
    }

    const connection = this.connections.get(name);
    if (!connection) {
      throw new ServerError("Server connection not found", { server: name });
    }
    return await connection.stop(disable);
  }


  async handleConfigUpdated(newConfig, changes) {
    try {
      const isSignificant = !!changes ? (changes.added?.length > 0 || changes.removed?.length > 0 || changes.modified?.length > 0) : false
      this.emit("configChangeDetected", { newConfig, isSignificant })
      //Even when some error occured on reloading, send the event to clients
      if (!newConfig || !changes) {
        return
      }
      if (!isSignificant) {
        logger.debug("No significant config changes detected")
        return;
      }
      this.emit("importantConfigChanged", changes);
      const addPromises = changes.added.map(async (name) => {
        const serverConfig = newConfig.mcpServers[name];
        await this.connectServer(name, serverConfig);
        logger.info(`Added new server '${name}'`)
      })

      const removePromises = changes.removed.map(async (name) => {
        await this.disconnectServer(name);
        this.connections.delete(name); // Clean up the connection
        logger.info(`Removed server ${name}`)
      })

      const modifiedPromises = changes.modified.map(async (name) => {
        const serverConfig = newConfig.mcpServers[name];
        const connection = this.connections.get(name);
        if (!!serverConfig.disabled !== !!connection?.disabled) {
          if (serverConfig.disabled) {
            await this.stopServer(name, true)
            logger.info(`Server '${name}' disabled`)
          } else {
            await this.startServer(name, serverConfig);
            logger.info(`Server '${name}' enabled`)
          }
        } else {
          // For other changes, reconnect with new config
          await this.disconnectServer(name);
          await this.connectServer(name, serverConfig);
          logger.info(`Updated server '${name}'`)
        }
      })
      await Promise.allSettled([
        ...addPromises,
        ...removePromises,
        ...modifiedPromises,
      ])
      this.emit("importantConfigChangeHandled", changes);
    } catch (error) {
      logger.error(
        error.code || "CONFIG_UPDATE_ERROR",
        error.message || "Error updating configuration",
        {
          error: error.message,
          changes,
        },
        false
      )
      this.emit("importantConfigChangeHandled", changes);
    }
  }

  async connectServer(name, config) {
    let connection = this.getConnection(name)
    if (!connection) {
      connection = new MCPConnection(name, config, this.marketplace, this.hubServerUrl);
      this.connections.set(name, connection);
    }
    await connection.connect(config);
    return connection.getServerInfo();
  }

  async disconnectServer(name) {
    const connection = this.connections.get(name);
    if (connection) {
      try {
        await connection.disconnect();
      } catch (error) {
        // Log but don't throw since we're cleaning up
        logger.error(
          "SERVER_DISCONNECT_ERROR",
          `Error disconnecting server: ${error.message}`,
          {
            server: name,
            error: error.message,
          },
          false
        );
      }
      // Don't remove from connections map
    }
  }
  getConnection(server_name) {
    const connection = this.connections.get(server_name);
    return connection
  }

  async cleanup() {
    logger.info("Starting MCP Hub cleanup");

    // Stop config file watching
    if (this.shouldWatchConfig) {
      logger.debug("Stopping config file watcher");
      this.configManager.stopWatching();
    }

    // Disconnect all servers
    await this.disconnectAll();

    logger.info("MCP Hub cleanup completed");
  }

  async disconnectAll() {
    const serverNames = Array.from(this.connections.keys());
    logger.info(`Disconnecting all servers in parallel`, {
      count: serverNames.length,
    });

    const results = await Promise.allSettled(
      serverNames.map((name) => this.disconnectServer(name))
    );

    const successful = results.filter((r) => r.status === "fulfilled");
    const failed = results
      .filter((r) => r.status === "rejected")
      .map((r, i) => ({
        name: serverNames[i],
        error: r.reason?.message || "Unknown error",
      }));

    // Log failures
    failed.forEach(({ name, error }) => {
      logger.error(
        "SERVER_DISCONNECT_ERROR",
        "Failed to disconnect server during cleanup",
        {
          server: name,
          error,
        },
        false
      );
    });

    if (serverNames.length) {
      logger.info(`${successful.length} servers disconnected`, {
        total: serverNames.length,
        successful: successful.length,
        failed: failed.length,
        failedServers: failed.map((f) => f.name),
      });
    }
    // Ensure connections map is cleared even if some disconnections failed
    this.connections.clear();
  }

  getServerStatus(name) {
    const connection = this.connections.get(name);
    if (!connection) {
      throw new ServerError("Server not found", { server: name });
    }
    return connection.getServerInfo();
  }

  getAllServerStatuses() {
    return Array.from(this.connections.values()).map((connection) =>
      connection.getServerInfo()
    );
  }

  async rawRequest(serverName, ...rest) {
    const connection = this.connections.get(serverName);
    if (!connection) {
      throw new ServerError("Server not found", {
        server: serverName,
      });
    }
    return await connection.raw_request(...rest);
  }
  async callTool(serverName, toolName, args, request_options) {
    const connection = this.connections.get(serverName);
    if (!connection) {
      throw new ServerError("Server not found", {
        server: serverName,
        operation: "tool_call",
        tool: toolName,
      });
    }
    return await connection.callTool(toolName, args, request_options);
  }

  async readResource(serverName, uri, request_options) {
    const connection = this.connections.get(serverName);
    if (!connection) {
      throw new ServerError("Server not found", {
        server: serverName,
        operation: "resource_read",
        uri,
      });
    }
    return await connection.readResource(uri, request_options);
  }

  async getPrompt(serverName, promtName, args, request_options) {
    const connection = this.connections.get(serverName);
    if (!connection) {
      throw new ServerError("Server not found", {
        server: serverName,
        operation: "get_prompt",
        prompt: promtName,
      });
    }
    return await connection.getPrompt(promtName, args, request_options);
  }

  async refreshServer(name) {
    const connection = this.connections.get(name);
    if (!connection) {
      throw new ServerError("Server not found", { server: name });
    }

    logger.info(`Refreshing capabilities for server '${name}'`);
    await connection.updateCapabilities();
    return connection.getServerInfo();
  }

  async refreshAllServers() {
    logger.debug("Refreshing capabilities from all servers");
    const serverNames = Array.from(this.connections.keys());

    const results = await Promise.allSettled(
      serverNames.map(async (name) => {
        try {
          const connection = this.connections.get(name);
          await connection.updateCapabilities();
          return connection.getServerInfo();
        } catch (error) {
          logger.error(
            "CAPABILITIES_REFRESH_ERROR",
            `Failed to refresh capabilities for server ${name}`,
            {
              server: name,
              error: error.message,
            },
            false
          );
          return {
            name,
            status: "error",
            error: error.message,
          };
        }
      })
    );
    logger.debug("Refreshed all servers")

    return results.map((result) =>
      result.status === "fulfilled" ? result.value : result.reason
    );
  }
}

export { MCPConnection } from "./MCPConnection.js";

