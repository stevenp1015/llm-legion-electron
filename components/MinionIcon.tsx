import React from 'react';

// Simple hash function to get a color from a string
const nameToColor = (name: string): string => {
  let hash = 0;
  if (name.length === 0) return 'bg-gray-500';
  for (let i = 0; i < name.length; i++) {
    hash = name.charCodeAt(i) + ((hash << 5) - hash);
    hash = hash & hash; // Ensure 32bit integer
  }
  // A palette of Tailwind CSS background gradients for a more dynamic look.
  const gradients = [
    'bg-gradient-to-br from-red-500 to-orange-600',
    'bg-gradient-to-br from-amber-500 to-yellow-600',
    'bg-gradient-to-br from-lime-500 to-green-600',
    'bg-gradient-to-br from-emerald-500 to-teal-600',
    'bg-gradient-to-br from-cyan-500 to-sky-600',
    'bg-gradient-to-br from-blue-500 to-indigo-600',
    'bg-gradient-to-br from-violet-500 to-purple-600',
    'bg-gradient-to-br from-fuchsia-500 to-pink-600',
    'bg-gradient-to-br from-rose-500 to-red-600',
  ];
  const index = Math.abs(hash) % gradients.length;
  // Return a gradient class from the palette based on the hash
  return gradients[index];
};

interface MinionIconProps {
  name: string;
  className?: string;
  title?: string;
}

const MinionIcon: React.FC<MinionIconProps> = ({ name, className = "w-8 h-8", title }) => {
  const bgColor = nameToColor(name);
  const initial = name ? name.charAt(0).toUpperCase() : '?';

  return (
    <div
      title={title || `Minion: ${name}`}
      className={`${className} ${bgColor} rounded-full flex items-center justify-center font-bold text-white text-lg select-none flex-shrink-0 shadow-lg ring-1 ring-white/30`}
    >
      <span className="drop-shadow-md">{initial}</span>
    </div>
  );
};

export default MinionIcon;
