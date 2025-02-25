import { useState, useRef, useLayoutEffect, useCallback } from 'react';
import { ScrollView } from 'react-native';
import { SCROLL_MODES, ScrollMode } from '../types';

export function useScrollMode(scrollViewRef: React.RefObject<ScrollView>) {
  const [scrollMode, setScrollMode] = useState<ScrollMode>(SCROLL_MODES.NORMAL);
  const scrollStartPosition = useRef<{ x: number; y: number } | null>(null);
  const scrollVelocity = useRef<{ x: number; y: number }>({ x: 0, y: 0 });
  const isScrolling = useRef(false);
  const lastCursorPosition = useRef<{ x: number; y: number } | null>(null);
  const scrollAnimationFrame = useRef<number | null>(null);
  const [scrollPosition, setScrollPosition] = useState({ x: 0, y: 0 });

  // Toggle scroll mode
  const toggleScrollMode = useCallback(() => {
    setScrollMode(prev => 
      prev === SCROLL_MODES.NORMAL ? SCROLL_MODES.CURSOR : SCROLL_MODES.NORMAL
    );
  }, []);

  // Handle keyboard events for scroll mode
  useLayoutEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'm' || e.key === 'M') {
        e.preventDefault();
        toggleScrollMode();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [toggleScrollMode]);

  // Handle mouse events for cursor scroll mode
  useLayoutEffect(() => {
    if (scrollMode !== SCROLL_MODES.CURSOR || typeof window === 'undefined') {
      return;
    }

    const handleMouseDown = (e: MouseEvent) => {
      if (scrollMode === SCROLL_MODES.CURSOR) {
        scrollStartPosition.current = { x: e.clientX, y: e.clientY };
        lastCursorPosition.current = { x: e.clientX, y: e.clientY };
        isScrolling.current = true;
      }
    };

    const handleMouseMove = (e: MouseEvent) => {
      if (scrollMode === SCROLL_MODES.CURSOR && isScrolling.current && scrollStartPosition.current && lastCursorPosition.current) {
        const dx = e.clientX - lastCursorPosition.current.x;
        const dy = e.clientY - lastCursorPosition.current.y;
        
        scrollVelocity.current = { x: dx, y: dy };
        lastCursorPosition.current = { x: e.clientX, y: e.clientY };
        
        if (scrollViewRef.current) {
          scrollViewRef.current.scrollTo({
            x: scrollPosition.x - dx,
            y: scrollPosition.y - dy,
            animated: false
          });
          
          setScrollPosition(prev => ({
            x: prev.x - dx,
            y: prev.y - dy
          }));
        }
      }
    };

    const handleMouseUp = () => {
      isScrolling.current = false;
      scrollStartPosition.current = null;
      lastCursorPosition.current = null;
    };

    window.addEventListener('mousedown', handleMouseDown);
    window.addEventListener('mousemove', handleMouseMove);
    window.addEventListener('mouseup', handleMouseUp);

    return () => {
      window.removeEventListener('mousedown', handleMouseDown);
      window.removeEventListener('mousemove', handleMouseMove);
      window.removeEventListener('mouseup', handleMouseUp);
    };
  }, [scrollMode, scrollPosition, scrollViewRef]);

  return {
    scrollMode,
    toggleScrollMode,
    scrollPosition,
    setScrollPosition
  };
} 