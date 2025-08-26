import json
import os
import subprocess
from datetime import datetime
import asyncio
from mcp.types import TextContent
from pathlib import Path
from .state import state


def list_directory_tool():
    return {
        "name": "list_directory",
        "description": "Get a detailed listing of files and directories in the specified path, including type, size, and modification "
        "date. WHEN TO USE: When you need to explore the contents of a directory, understand what files are available, check file sizes or "
        "modification dates, or locate specific files by name. WHEN NOT TO USE: When you need to read the contents of files (use read_file "
        "instead), when you need a recursive listing of all subdirectories (use directory_tree instead), or when searching for files by name pattern "
        "(use search_files instead). RETURNS: Text with each line containing file type ([DIR]/[FILE]), name, size (in B/KB/MB), and "
        "modification date. Only works within the allowed directory. Example: Enter 'src' to list contents of the src directory, or '.' for "
        "current directory.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path of the directory to list. Examples: '.' for current directory, 'src' for src directory, 'docs/images' for a nested directory. The path must be within the allowed workspace.",
                }
            },
            "required": ["path"],
        },
    }


async def handle_list_directory(arguments: dict):
    from mcp.types import TextContent

    path = arguments.get("path", ".")

    # Determine full path based on whether input is absolute or relative
    if os.path.isabs(path):
        full_path = os.path.abspath(path)  # Just normalize the absolute path
    else:
        # For relative paths, join with allowed_directory
        full_path = os.path.abspath(os.path.join(state.allowed_directory, path))

    if not full_path.startswith(state.allowed_directory):
        raise ValueError(f"Access denied: Path ({full_path}) must be within allowed directory ({state.allowed_directory})")
    if not os.path.exists(full_path):
        raise ValueError(f"Path does not exist: {full_path}")
    if not os.path.isdir(full_path):
        raise ValueError(f"Path is not a directory: {full_path}")

    # List directory contents
    entries = []
    try:
        with os.scandir(full_path) as it:
            for entry in it:
                try:
                    stat = entry.stat()
                    # Format size to be human readable
                    size = stat.st_size
                    if size >= 1024 * 1024:  # MB
                        size_str = f"{size / (1024 * 1024):.1f}MB"
                    elif size >= 1024:  # KB
                        size_str = f"{size / 1024:.1f}KB"
                    else:  # bytes
                        size_str = f"{size}B"

                    entry_type = "[DIR]" if entry.is_dir() else "[FILE]"
                    mod_time = datetime.fromtimestamp(stat.st_mtime).strftime("%Y-%m-%d %H:%M:%S")
                    entries.append(f"{entry_type} {entry.name:<30} {size_str:>8} {mod_time}")
                except (OSError, PermissionError):
                    continue

        entries.sort()  # Sort entries alphabetically
        return [TextContent(type="text", text="\n".join(entries))]

    except PermissionError:
        raise ValueError(f"Permission denied accessing: {full_path}")


def create_directory_tool():
    return {
        "name": "create_directory",
        "description": "Create a new directory or ensure a directory exists. "
        "Can create multiple nested directories in one operation. "
        "WHEN TO USE: When you need to set up project structure, organize files, create output directories before saving files, or establish a directory hierarchy. "
        "WHEN NOT TO USE: When you only want to check if a directory exists (use get_file_info instead), or when trying to create directories outside the allowed workspace. "
        "RETURNS: Text message confirming either that the directory was successfully created or that it already exists. "
        "The operation succeeds silently if the directory already exists. "
        "Only works within the allowed directory. "
        "Example: Enter 'src/components' to create nested directories.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path of the directory to create. Can include nested directories which will all be created. Examples: 'logs' for a simple directory, 'src/components/buttons' for nested directories. Both absolute and relative paths are supported, but must be within the allowed workspace.",
                }
            },
            "required": ["path"],
        },
    }


async def handle_create_directory(arguments: dict):
    """Handle creating a new directory."""
    from mcp.types import TextContent

    path = arguments.get("path")
    if not path:
        raise ValueError("path must be provided")

    # Determine full path based on whether input is absolute or relative
    if os.path.isabs(path):
        full_path = os.path.abspath(path)  # Just normalize the absolute path
    else:
        # For relative paths, join with allowed_directory
        full_path = os.path.abspath(os.path.join(state.allowed_directory, path))

    # Security check: ensure path is within allowed directory
    if not full_path.startswith(state.allowed_directory):
        raise ValueError(f"Access denied: Path ({full_path}) must be within allowed directory ({state.allowed_directory})")

    already_exists = os.path.exists(full_path)

    try:
        # Create directory and any necessary parent directories
        os.makedirs(full_path, exist_ok=True)

        if already_exists:
            return [TextContent(type="text", text=f"Directory already exists: {path}")]
        return [TextContent(type="text", text=f"Successfully created directory: {path}")]
    except PermissionError:
        raise ValueError(f"Permission denied creating directory: {path}")
    except Exception as e:
        raise ValueError(f"Error creating directory: {str(e)}")


def directory_tree_tool():
    return {
        "name": "directory_tree",
        "description": "Get a recursive tree view of files and directories in the specified path as a JSON structure. "
        "WHEN TO USE: When you need to understand the complete structure of a directory tree, visualize the hierarchy of files and directories, or get a comprehensive overview of a project's organization. "
        "Particularly useful for large projects where you need to see nested relationships. "
        "WHEN NOT TO USE: When you only need a flat list of files in a single directory (use directory_listing instead), or when you're only interested in specific file types (use search_files instead). "
        "RETURNS: JSON structure where each entry includes 'name', 'type' (file/directory), and 'children' for directories. "
        "Files have no children array, while directories always have a children array (which may be empty). "
        "The output is formatted with 2-space indentation for readability. For Git repositories, shows tracked files only. "
        "Only works within the allowed directory and only for non-hidden files, or files that are not inside hidden directory. "
        "If you want to show the hidden files also, use commands like execute_shell_script. "
        "Example: Enter '.' for current directory, or 'src' for a specific directory.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Root directory to analyze. This is the starting point for the recursive tree generation. Examples: '.' for current directory, 'src' for the src directory. Both absolute and relative paths are supported, but must be within the allowed workspace.",
                },
                "max_depth": {
                    "type": "integer",
                    "description": "Max depth for traversing in case of big and deeply nested directory",
                    "default": 3,
                },
            },
            "required": ["path"],
        },
    }


async def handle_directory_tree(arguments: dict):
    """Handle building a directory tree."""
    path = arguments.get("path", ".")
    max_depth = arguments.get("max_depth", 3)

    # Validate and get full path
    full_path = os.path.abspath(os.path.join(state.allowed_directory, path))
    if not os.path.abspath(full_path).startswith(state.allowed_directory):
        raise ValueError(f"Access denied: Path ({full_path}) must be within allowed directory ({state.allowed_directory})")
    if not os.path.exists(full_path):
        raise ValueError(f"Path does not exist: {full_path}")
    if not os.path.isdir(full_path):
        raise ValueError(f"Path is not a directory: {full_path}")

    """
    Idea: for git repo directory, use git ls-files to list all the files
    So that we can avoid some gigantic directories like node_modules, build, dist
    Else just use normal listing
    1. Try git ls-files for this directory
    2. If failed, identify git repo by rg and sed -> find -> python, 
       git ls-files then add to the visited
    3. List the remaining that is not in visited using rg -> find -> python
    """
    root = {"name": full_path, "type": "directory", "children": []}
    dir_cache = {"": root}
    try:
        paths = await git_ls(Path(full_path))
        build_tree_from_paths(root, dir_cache, paths, max_depth)
        json_tree = json.dumps(root, indent=2)
        return [TextContent(type="text", text=json_tree)]
    except Exception:
        pass

    # build the tree for git repo
    try:
        git_repos = await find_git_repo_async(full_path)
    except Exception:
        git_repos = find_git_repos_python(Path(full_path))
    for git_repo in git_repos:
        absolute_git_repo = Path(full_path) / git_repo
        paths = []
        try:
            paths = await git_ls(absolute_git_repo)
        except Exception:
            try:
                paths = await scan_path_async([], absolute_git_repo)
            except Exception:
                paths = scan_path([], absolute_git_repo)
        finally:
            paths = [git_repo / path for path in paths]
            build_tree_from_paths(root, dir_cache, paths, max_depth)

    # for non-git directory, do normal scan
    non_git_scans = []
    try:
        non_git_scans = await scan_path_async(git_repos, Path(full_path))
    except Exception:
        non_git_scans = scan_path(git_repos, Path(full_path))
    finally:
        build_tree_from_paths(root, dir_cache, non_git_scans, max_depth)
        json_tree = json.dumps(root, indent=2)
        return [TextContent(type="text", text=json_tree)]


async def find_git_repo_async(cwd: str) -> list[Path]:
    # ripgrep first then find
    try:
        cmd = r"rg --files --glob '**/.git/HEAD' --hidden | sed 's|/\.git/HEAD$|/.git|'"
        proc = await asyncio.create_subprocess_shell(
            cmd,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        stdout, stderr = await proc.communicate()

        if proc.returncode not in [0, 1]:  # 0 = success, 1 = some files not found (normal)
            stderr_text = stderr.decode().strip()
            if stderr_text:  # If there's stderr content, it's likely a real error
                raise Exception(f"Find command error: {stderr_text}")

        git_dirs = stdout.decode().strip().splitlines()
        repo_paths: list[Path] = []
        for git_dir in git_dirs:
            if git_dir:  # Skip empty lines
                # Convert to Path object and get parent (removes .git)
                repo_relative_path = Path(git_dir).parent
                repo_paths.append(repo_relative_path)
        return repo_paths

    except Exception:
        pass

    cmd = r"find . -name .git -type d ! -path '*/\.*/*'"
    proc = await asyncio.create_subprocess_shell(
        cmd,
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    stdout, stderr = await proc.communicate()

    if proc.returncode not in [0, 1]:  # 0 = success, 1 = some files not found (normal)
        stderr_text = stderr.decode().strip()
        if stderr_text:  # If there's stderr content, it's likely a real error
            raise Exception(f"Find command error: {stderr_text}")

    git_dirs = stdout.decode().strip().splitlines()
    repo_paths: list[Path] = []

    for git_dir in git_dirs:
        if git_dir:  # Skip empty lines
            # Convert to Path object and get parent (removes .git)
            repo_relative_path = Path(git_dir).parent
            repo_paths.append(repo_relative_path)
    return repo_paths


def find_git_repos_python(start_path: Path) -> list[Path]:
    r"""
    Python fallback for: find . -name .git -type d ! -path '*/\.*/*'

    Finds all .git directories, excluding those inside hidden directories.

    Args:
        start_path: Starting directory (defaults to current directory)

    Returns:
        List of Path objects pointing to .git directories
    """
    git_dirs = []
    start_str = str(start_path)

    for root, dirs, _ in os.walk(start_str, followlinks=False):
        # Remove hidden directories from traversal
        dirs[:] = [d for d in dirs if not d.startswith(".") and d != "node_modules"]
        # Check if current directory contains .git
        if ".git" in dirs:
            # Calculate relative path
            rel_root = os.path.relpath(root, start_str)
            if rel_root == ".":
                git_path = ".git"
            else:
                git_path = rel_root + "/.git"

            git_dirs.append(Path(git_path))

            # Remove .git from further traversal (we don't need to go inside it)
            dirs.remove(".git")

    return git_dirs


async def git_ls(git_cwd: Path) -> list[Path]:
    cmd = r"git ls-files"
    proc = await asyncio.create_subprocess_shell(cmd, cwd=git_cwd, stderr=subprocess.PIPE, stdout=subprocess.PIPE)
    stdout, stderr = await proc.communicate()
    if proc.returncode != 0:
        stderr_text = stderr.decode().strip()
        raise Exception(f"Command error with status {proc.returncode}: {stderr_text}")

    paths = stdout.decode().strip().splitlines()
    paths = [Path(path) for path in paths if path]
    return paths


def build_tree_from_paths(root: dict, dir_cache: dict, paths: list[Path], max_depth: int):
    paths = [path for path in paths if len(path.parts) <= max_depth]

    for path in paths:
        parts = path.parts
        current_path = ""
        current = root
        n = len(parts)

        for i, part in enumerate(parts):
            if i == n - 1:
                current["children"].append({"name": part, "type": "file"})
            else:
                current_path = str(Path(current_path) / part) if current_path else part

                if current_path not in dir_cache:
                    new_dir = {"name": part, "type": "directory", "children": []}
                    current["children"].append(new_dir)
                    dir_cache[current_path] = new_dir

                current = dir_cache[current_path]


def scan_path(ignore_paths: list[Path], cwd: Path) -> list[Path]:
    # ignore_paths relative to cwd
    ignore_absolute = {(cwd / ignore_path).resolve() for ignore_path in ignore_paths}
    files: list[Path] = []
    for root, dirs, filenames in os.walk(cwd):
        root_path = Path(root)

        # Remove hidden directories from dirs list (modifies os.walk behavior)
        dirs[:] = [d for d in dirs if not d.startswith(".")]

        # Remove ignored directories from dirs list
        dirs[:] = [d for d in dirs if (root_path / d).resolve() not in ignore_absolute]

        # Add non-hidden files
        for filename in filenames:
            if not filename.startswith(".") and "node_modules" not in root_path.parts:                file_path = root_path / filename
                # Return path relative to cwd
                files.append(file_path.relative_to(cwd))

    return files


async def scan_path_async(ignore_paths: list[Path], cwd: Path) -> list[Path]:
    # try ripgrep first, then find
    try:
        rgignore = " ".join(f"--glob '!{path}/**'" for path in ignore_paths)
        rgcmd = rf"rg --files {rgignore} ."

        proc = await asyncio.create_subprocess_shell(
            rgcmd,
            cwd=cwd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        stdout, stderr = await proc.communicate()

        if proc.returncode in [0, 1]:
            paths = []
            for line in stdout.decode().strip().splitlines():
                if line:
                    paths.append(Path(line))
            return paths
    except Exception:
        pass

    ignore_paths += [Path("backend")]

    findignore = " ".join(f"-path './{path}' -prune -o" for path in ignore_paths)
    findcmd = f"find . {findignore} -type f ! -path '*/.*/*' ! -name '.*' -print"

    proc = await asyncio.create_subprocess_shell(
        findcmd,
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    stdout, stderr = await proc.communicate()

    if proc.returncode not in [0, 1]:  # 0 = success, 1 = some files not found (normal)
        stderr_text = stderr.decode().strip()
        if stderr_text:  # If there's stderr content, it's likely a real error
            raise Exception(f"Find command error: {stderr_text}")

    paths = []
    for line in stdout.decode().strip().splitlines():
        if line:
            if line.startswith("./"):
                line = line[2:]
            if line:
                paths.append(Path(line))

    return paths
