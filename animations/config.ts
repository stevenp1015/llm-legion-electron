// Centralized animation configuration
// Because having animations scattered everywhere is fucking chaos

export const ANIMATION_DURATION = {
  instant: 0.1,
  fast: 0.2,
  normal: 0.3,
  slow: 0.5,
};

export const SPRING_CONFIG = {
  // For UI elements that need to feel responsive
  snappy: { 
    type: 'spring' as const, 
    stiffness: 500, 
    damping: 30,
    mass: 0.8
  },
  // For smooth, gentle animations
  gentle: { 
    type: 'spring' as const, 
    stiffness: 300, 
    damping: 30,
    mass: 1
  },
  // For bouncy, playful animations
  bouncy: { 
    type: 'spring' as const, 
    stiffness: 400, 
    damping: 20,
    mass: 1,
    bounce: 0.3
  },
  // For stiff, immediate responses
  stiff: {
    type: 'spring' as const,
    stiffness: 1000,
    damping: 30,
    mass: 0.5
  },
  // For satisfying button presses
  haptic: {
    type: 'spring' as const,
    stiffness: 800,
    damping: 25,
    mass: 0.6
  },
  // For morphing/shape changes
  morph: {
    type: 'spring' as const,
    stiffness: 350,
    damping: 35,
    mass: 0.9
  },
  // For elastic, rubber-band feel
  elastic: {
    type: 'spring' as const,
    stiffness: 200,
    damping: 15,
    mass: 1.2,
    bounce: 0.6
  },
  // For smooth slides and position changes
  slide: {
    type: 'spring' as const,
    stiffness: 450,
    damping: 40,
    mass: 0.7
  }
};

export const EASING = {
  easeOut: [0.4, 0, 0.2, 1] as [number, number, number, number],
  easeIn: [0.4, 0, 1, 1] as [number, number, number, number],
  easeInOut: [0.4, 0, 0.2, 1] as [number, number, number, number],
  linear: [0, 0, 1, 1] as [number, number, number, number],
};

// Reduced motion check for accessibility
export const prefersReducedMotion = () => {
  if (typeof window === 'undefined') return false;
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
};

// Get animation config based on user preference
export const getAnimationConfig = (type: keyof typeof SPRING_CONFIG) => {
  if (prefersReducedMotion()) {
    return { duration: 0.01 }; // Nearly instant for reduced motion
  }
  return SPRING_CONFIG[type];
};

// Advanced animation variants for specific UI patterns
export const ANIMATION_VARIANTS = {
  // Channel selection with smooth slide + morph
  channelSelection: {
    inactive: { 
      scale: 1,
      opacity: 0,
      x: -8,
      transition: getAnimationConfig('snappy')
    },
    active: { 
      scale: 1,
      opacity: 1,
      x: 0,
      transition: getAnimationConfig('morph')
    },
    hover: {
      scale: 1.02,
      transition: getAnimationConfig('haptic')
    }
  },
  
  // Message entrance with satisfying bounce
  messageEntry: {
    hidden: { 
      opacity: 0, 
      y: 20, 
      scale: 0.9,
      filter: 'blur(4px)'
    },
    visible: { 
      opacity: 1, 
      y: 0, 
      scale: 1,
      filter: 'blur(0px)',
      transition: {
        ...getAnimationConfig('slide'),
        filter: { duration: 0.3 }
      }
    },
    exit: { 
      opacity: 0, 
      y: -10, 
      scale: 0.95,
      transition: getAnimationConfig('gentle')
    }
  },

  // Button interactions that feel tactile
  button: {
    idle: { scale: 1, opacity: 0.8 },
    hover: { 
      scale: 1.05, 
      opacity: 1,
      transition: getAnimationConfig('haptic')
    },
    tap: { 
      scale: 0.95,
      transition: { 
        ...getAnimationConfig('stiff'),
        duration: 0.1
      }
    }
  },

  // Typing indicator with personality
  typing: {
    animate: {
      scale: [1, 1.2, 1],
      opacity: [0.5, 1, 0.5],
      transition: {
        duration: 1.2,
        repeat: Infinity,
        ease: 'easeInOut'
      }
    }
  },

  // Modal/panel slide-in
  panel: {
    hidden: { 
      opacity: 0,
      x: 300,
      scale: 0.9
    },
    visible: { 
      opacity: 1,
      x: 0,
      scale: 1,
      transition: getAnimationConfig('slide')
    }
  }
};

// Shimmer effect for loading states
export const shimmerKeyframes = {
  '0%': { transform: 'translateX(-100%)' },
  '100%': { transform: 'translateX(100%)' }
};

// Utility for staggered animations
export const staggerContainer = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: {
      staggerChildren: 0.1,
      delayChildren: 0.2
    }
  }
};
