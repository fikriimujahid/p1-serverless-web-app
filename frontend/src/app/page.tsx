'use client';

import React from 'react';
import { useRouter } from 'next/navigation';
import { LandingHeader } from '@/components/landing/LandingHeader';
import { Hero } from '@/components/landing/Hero';
import { Features } from '@/components/landing/Features';
import { Architecture } from '@/components/landing/Architecture';
import { Mockups } from '@/components/landing/Mockups';
import { CTASection } from '@/components/landing/CTASection';
import { Footer } from '@/components/landing/Footer';

export default function LandingPage() {
  const router = useRouter();

  const handleGetStarted = () => {
    router.push('/signup');
  };

  const handleViewDocs = () => {
    const featuresSection = document.getElementById('features');
    if (featuresSection) {
      featuresSection.scrollIntoView({ behavior: 'smooth' });
    }
  };

  return (
    <div className="min-h-screen bg-background">
      <LandingHeader onGetStarted={handleGetStarted} />
      
      <main>
        <Hero onGetStarted={handleGetStarted} onViewDocs={handleViewDocs} />
        <Features />
        <Architecture />
        <Mockups />
        <CTASection onGetStarted={handleGetStarted} />
      </main>

      <Footer />
    </div>
  );
}