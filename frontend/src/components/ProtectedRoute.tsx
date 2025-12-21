'use client';

import { useRouter } from 'next/navigation';
import { useAuth } from '@/lib/auth';
import React, { ReactNode, useEffect } from 'react';

type ProtectedRouteProps = {
  children: ReactNode;
};

export function ProtectedRoute({ children }: ProtectedRouteProps) {
  const { isAuthenticated, isLoading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      router.push('/');
    }
  }, [isAuthenticated, isLoading, router]);

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div
          className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"
          role="status"
          aria-label="Loading"
        ></div>
      </div>
    );
  }

  if (!isAuthenticated) {
    return null; // Will redirect via useEffect
  }

  return <>{children}</>;
}
