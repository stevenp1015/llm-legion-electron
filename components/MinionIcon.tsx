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
    'bg-gradient-to-br from-red-500 via-red-700 to-pink-700',
    'bg-gradient-to-br from-orange-500 via-orange-700 to-yellow-700',
    'bg-gradient-to-br from-green-500 via-green-700 to-teal-700',
    'bg-gradient-to-br from-cyan-500 via-cyan-700 to-blue-700',
    'bg-gradient-to-br from-purple-500 via-purple-700 to-indigo-700',
    'bg-gradient-to-br from-pink-500 via-pink-700 to-purple-700',
    'bg-gradient-to-br from-red-500 via-red-700 to-orange-700',
    'bg-gradient-to-br from-amber-500 via-amber-700 to-yellow-700',
    'bg-gradient-to-br from-lime-500 via-lime-700 to-green-700',
    'bg-gradient-to-br from-emerald-500 via-emerald-700 to-teal-700',
    'bg-gradient-to-br from-cyan-500 via-cyan-700 to-sky-700',
    'bg-gradient-to-br from-blue-500 via-blue-700 to-indigo-700',
    'bg-gradient-to-br from-violet-500 via-violet-700 to-purple-700',
    'bg-gradient-to-br from-fuchsia-500 via-fuchsia-700 to-pink-700',
    'bg-gradient-to-br from-rose-500  via-rose-700 to-red-700',
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
      className={`${className} ${bgColor} rounded-full flex items-center justify-center font-bold text-white text-lg select-none flex-shrink-0 shadow-2xl ring-1 ring-white/30`}
    >
      <span className="drop-shadow-md">{initial}</span>
    </div>
  );
};

export default MinionIcon;
