import React from 'react';
import { RegulatorReport } from '../types';
import MinionIcon from './MinionIcon';

const ProgressBar: React.FC<{ value: number }> = ({ value }) => {
    const color = value > 66 ? 'bg-green-500' : value > 33 ? 'bg-yellow-500' : 'bg-red-500';
    return (
        <div className="w-full bg-zinc-200 rounded-full h-2.5">
            <div className={`${color} h-2.5 rounded-full`} style={{ width: `${value}%` }}></div>
        </div>
    );
};

const sentimentStyles: Record<RegulatorReport['overall_sentiment'], { color: string, text: string }> = {
    positive: { color: 'text-green-600', text: 'Positive' },
    negative: { color: 'text-red-600', text: 'Negative' },
    neutral: { color: 'text-neutral-600', text: 'Neutral' },
    mixed: { color: 'text-yellow-600', text: 'Mixed' },
};


const RegulatorReportCard: React.FC<{ report: RegulatorReport, minionName: string }> = ({ report, minionName }) => {
    const sentiment = sentimentStyles[report.overall_sentiment] || sentimentStyles.neutral;

    return (
        <div className="mt-2 p-4 w-full bg-teal-50 border border-teal-200 rounded-lg shadow-lg">
            <h4 className="text-sm font-bold text-teal-700 mb-3 flex items-center gap-2">
                <MinionIcon name={minionName} className="w-5 h-5" />
                <span>Chat Status Report | Regulator: {minionName}</span>
            </h4>
            
            <div className="space-y-4 text-sm">
                <div>
                    <p className="text-xs text-neutral-500 font-semibold mb-1">Inferred Goal</p>
                    <p className="text-neutral-700 italic">"{report.conversation_goal_inference}"</p>
                </div>

                <div className="grid grid-cols-2 gap-4">
                    <div>
                        <p className="text-xs text-neutral-500 font-semibold mb-1">On-Topic Score: {report.on_topic_score}%</p>
                        <ProgressBar value={report.on_topic_score} />
                    </div>
                     <div>
                        <p className="text-xs text-neutral-500 font-semibold mb-1">Progress Score: {report.progress_score}%</p>
                        <ProgressBar value={report.progress_score} />
                    </div>
                </div>

                <div className="grid grid-cols-2 gap-4">
                    <div>
                         <p className="text-xs text-neutral-500 font-semibold mb-1">Overall Sentiment</p>
                         <p className={`font-bold ${sentiment.color}`}>{sentiment.text}</p>
                    </div>
                     <div>
                        <p className="text-xs text-neutral-500 font-semibold mb-1">Is Stalled or Looping?</p>
                        <p className={`font-bold ${report.is_stalled_or_looping ? 'text-red-600' : 'text-green-600'}`}>
                            {report.is_stalled_or_looping ? 'Yes' : 'No'}
                        </p>
                    </div>
                </div>

                <div>
                    <p className="text-xs text-neutral-500 font-semibold mb-1">Summary</p>
                    <p className="text-neutral-600 bg-zinc-100 p-2 rounded-md text-xs">{report.summary_of_discussion}</p>
                </div>

                {report.suggested_next_steps && report.suggested_next_steps.length > 0 && (
                    <div>
                        <p className="text-xs text-neutral-500 font-semibold mb-2">Suggested Next Steps</p>
                        <ul className="space-y-1.5">
                            {report.suggested_next_steps.map((step, index) => (
                                <li key={index} className="flex items-start gap-2 text-teal-700 text-xs">
                                    <span className="text-teal-600 mt-0.5">&rarr;</span>
                                    <span>{step}</span>
                                </li>
                            ))}
                        </ul>
                    </div>
                )}
            </div>
        </div>
    );
};

export default RegulatorReportCard;