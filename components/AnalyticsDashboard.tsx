import React, { useState, useEffect, useMemo, useCallback } from 'react';
import { MinionConfig, ModelQuotas, UsageStat } from '../types';
import { XMarkIcon, ArrowPathIcon } from './Icons';
import legionApiService from '../services/legionApiService';
import MinionIcon from './MinionIcon';

interface AnalyticsDashboardProps {
    isOpen: boolean;
    onClose: () => void;
    minionConfigs: MinionConfig[];
}

interface MinionAnalyticsData {
    id: string;
    name: string;
    role: 'standard' | 'regulator';
    currentUsage?: { rpm: number; tpm: number; rpd: number };
    quotas?: ModelQuotas;
    cumulativeStats: {
        requests: number;
        promptTokens: number;
        completionTokens: number;
        totalTokens: number;
    };
}

const StatCard: React.FC<{ title: string; value: string; subtext?: string }> = ({ title, value, subtext }) => (
    <div className="bg-white/50 p-4 rounded-lg shadow-sm">
        <p className="text-sm text-neutral-500">{title}</p>
        <p className="text-2xl font-bold text-neutral-800">{value}</p>
        {subtext && <p className="text-xs text-neutral-400">{subtext}</p>}
    </div>
);

const formatNumber = (num: number) => new Intl.NumberFormat('en-US').format(num);
const formatTpm = (tpm?: number) => {
    if (tpm === undefined) return 'N/A';
    return tpm >= 1000 ? `${formatNumber(Math.round(tpm / 1000))}k` : formatNumber(tpm);
}

const RateLimitDisplay: React.FC<{usage?: {rpm: number, tpm: number, rpd: number}, quotas?: ModelQuotas}> = ({usage, quotas}) => {
    if (!quotas || !usage) {
        return <p className="text-xs text-neutral-500 font-mono">Not Monitored</p>;
    }

    const isUnmonitored = quotas.rpm >= 9999;
    if (isUnmonitored) {
       return <p className="text-xs text-neutral-500 font-mono">Not Monitored</p>;
    }

    const isSharedRpdOnly = quotas.sharedPool && quotas.rpm >= 9999;
    
    return (
        <div className="text-xs mt-1 space-y-0.5 font-mono text-neutral-600">
            {!isSharedRpdOnly && (
                <>
                    <p>RPM: {formatNumber(usage.rpm)} / {formatNumber(quotas.rpm)}</p>
                    <p>TPM: {formatTpm(usage.tpm)} / {formatTpm(quotas.tpm)}</p>
                </>
            )}
            <p>RPD: {formatNumber(usage.rpd)} / {formatNumber(quotas.rpd)}</p>
        </div>
    )
}


const AnalyticsDashboard: React.FC<AnalyticsDashboardProps> = ({ isOpen, onClose, minionConfigs }) => {
    const [analyticsData, setAnalyticsData] = useState<MinionAnalyticsData[]>([]);
    const [startDate, setStartDate] = useState(() => {
        const d = new Date();
        d.setDate(d.getDate() - 7);
        return d.toISOString().split('T')[0];
    });
    const [endDate, setEndDate] = useState(() => new Date().toISOString().split('T')[0]);
    const [isLoading, setIsLoading] = useState(false);

    const fetchData = useCallback(async () => {
        if (!isOpen) return;
        setIsLoading(true);
        const start = new Date(startDate).getTime();
        const end = new Date(endDate).getTime() + (24 * 60 * 60 * 1000 - 1); // include the whole end day

        const data = await Promise.all(minionConfigs.map(async (minion) => {
            const stats = await legionApiService.getAnalyticsData(minion.id, start, end);
            return {
                id: minion.id,
                name: minion.name,
                role: minion.role,
                currentUsage: stats?.currentUsage,
                quotas: stats?.quotas,
                cumulativeStats: stats?.cumulativeStats || { requests: 0, promptTokens: 0, completionTokens: 0, totalTokens: 0},
            };
        }));
        setAnalyticsData(data);
        setIsLoading(false);
    }, [isOpen, minionConfigs, startDate, endDate]);

    useEffect(() => {
        fetchData();
    }, [fetchData]);
    
    const totals = useMemo(() => {
        return analyticsData.reduce((acc, minion) => {
            acc.requests += minion.cumulativeStats.requests;
            acc.promptTokens += minion.cumulativeStats.promptTokens;
            acc.completionTokens += minion.cumulativeStats.completionTokens;
            acc.totalTokens += minion.cumulativeStats.totalTokens;
            return acc;
        }, { requests: 0, promptTokens: 0, completionTokens: 0, totalTokens: 0});
    }, [analyticsData]);

    if (!isOpen) return null;

    return (
        <div className="fixed inset-0 z-50 flex flex-col bg-zinc-900/75 backdrop-blur-sm">
            <header className="flex-shrink-0 p-4 bg-zinc-50/80 backdrop-blur-sm border-b border-zinc-200 flex justify-between items-center">
                <h2 className="text-2xl font-bold text-neutral-800">Legion Analytics Dashboard</h2>
                <button onClick={onClose} className="p-2 text-neutral-500 hover:text-neutral-800 hover:bg-zinc-200 rounded-full">
                    <XMarkIcon className="w-7 h-7" />
                </button>
            </header>
            
            <div className="flex-grow p-6 overflow-y-auto scrollbar-thin scrollbar-thumb-neutral-400 scrollbar-track-zinc-200">
                <div className="mb-6 p-4 bg-zinc-100/60 rounded-lg flex items-center justify-between gap-4">
                    <h3 className="text-lg font-semibold text-neutral-800">Overall Legion Performance</h3>
                    <div className="flex items-center gap-4 text-neutral-700">
                        <label className="text-sm">From:</label>
                        <input type="date" value={startDate} onChange={e => setStartDate(e.target.value)} className="bg-zinc-200 text-neutral-800 p-2 rounded-md border border-zinc-300"/>
                        <label className="text-sm">To:</label>
                        <input type="date" value={endDate} onChange={e => setEndDate(e.target.value)} className="bg-zinc-200 text-neutral-800 p-2 rounded-md border border-zinc-300"/>
                        <button onClick={fetchData} disabled={isLoading} className="p-2 bg-teal-600 text-white rounded-md hover:bg-teal-700 disabled:bg-teal-400 disabled:cursor-not-allowed">
                            <ArrowPathIcon className={`w-5 h-5 ${isLoading ? 'animate-spin' : ''}`} />
                        </button>
                    </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
                    <StatCard title="Total Requests" value={formatNumber(totals.requests)} />
                    <StatCard title="Total Tokens Used" value={formatTpm(totals.totalTokens)} />
                    <StatCard title="Input Tokens" value={formatTpm(totals.promptTokens)} />
                    <StatCard title="Output Tokens" value={formatTpm(totals.completionTokens)} />
                </div>

                <div className="space-y-4">
                    {analyticsData.map(minion => (
                        <div key={minion.id} className={`p-4 bg-white/70 backdrop-blur-sm rounded-lg border-l-4 ${minion.role === 'regulator' ? 'border-amber-500' : 'border-teal-600'}`}>
                             <div className="flex items-center gap-3 mb-4">
                                <MinionIcon name={minion.name} className="w-8 h-8" />
                                <div>
                                    <h4 className="text-xl font-bold text-neutral-800">{minion.name}</h4>
                                    <p className="text-sm uppercase font-semibold tracking-wider" style={{color: minion.role === 'regulator' ? '#f59e0b' : '#0d9488'}}>{minion.role}</p>
                                </div>
                            </div>
                            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
                                <StatCard title="Requests" value={formatNumber(minion.cumulativeStats.requests)} />
                                <StatCard title="Total Tokens" value={formatTpm(minion.cumulativeStats.totalTokens)} />
                                <StatCard title="Input Tokens" value={formatTpm(minion.cumulativeStats.promptTokens)} />
                                <StatCard title="Output Tokens" value={formatTpm(minion.cumulativeStats.completionTokens)} />
                                <div className="bg-white/50 p-4 rounded-lg">
                                    <p className="text-sm text-neutral-500">Current Rate Limits</p>
                                    <RateLimitDisplay usage={minion.currentUsage} quotas={minion.quotas} />
                                </div>
                            </div>
                        </div>
                    ))}
                </div>
            </div>
        </div>
    );
};

export default AnalyticsDashboard;
