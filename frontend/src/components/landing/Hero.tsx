import React from 'react';
import { ArrowRight, BookOpen } from 'lucide-react';
import { Button } from '../ui/button';
import { ImageWithFallback } from '../ImageWithFallback';

interface HeroProps {
  onGetStarted: () => void;
  onViewDocs: () => void;
}

export function Hero({ onGetStarted, onViewDocs }: HeroProps) {
  return (
    <section className="relative overflow-hidden bg-gradient-to-br from-background via-background to-accent/20 pt-20 pb-16 md:pt-32 md:pb-24">
      {/* Background decoration */}
      <div className="absolute inset-0 -z-10 opacity-20">
        <div className="absolute top-0 right-0 w-96 h-96 bg-primary/10 rounded-full blur-3xl" />
        <div className="absolute bottom-0 left-0 w-96 h-96 bg-chart-1/10 rounded-full blur-3xl" />
      </div>

      <div className="container mx-auto px-4 md:px-6 lg:px-8">
        <div className="grid lg:grid-cols-2 gap-12 items-center">
          {/* Content */}
          <div className="space-y-6 md:space-y-8">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-accent text-accent-foreground border border-border">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-primary opacity-75"></span>
                <span className="relative inline-flex rounded-full h-2 w-2 bg-primary"></span>
              </span>
              <span className="text-sm">Serverless • Scalable • Secure</span>
            </div>

            <h1 className="text-4xl md:text-5xl lg:text-6xl font-bold tracking-tight">
              Your Ideas,{' '}
              <span className="bg-gradient-to-r from-primary to-chart-1 bg-clip-text text-transparent">
                Anywhere
              </span>
            </h1>

            <p className="text-lg md:text-xl text-muted-foreground max-w-xl">
              A production-grade serverless notes app built with AWS, Next.js, and Tailwind CSS. 
              Capture, organize, and sync your thoughts across all devices with enterprise-level security.
            </p>

            <div className="flex flex-col sm:flex-row gap-4 pt-4">
              <Button
                size="lg"
                onClick={onGetStarted}
                className="group relative overflow-hidden text-base md:text-lg px-6 md:px-8 py-5 md:py-6"
              >
                Get Started
                <ArrowRight className="ml-2 h-5 w-5 transition-transform group-hover:translate-x-1" />
              </Button>

              <Button
                size="lg"
                variant="outline"
                onClick={onViewDocs}
                className="text-base md:text-lg px-6 md:px-8 py-5 md:py-6"
              >
                <BookOpen className="mr-2 h-5 w-5" />
                View Docs
              </Button>
            </div>

            {/* Stats */}
            <div className="flex flex-wrap gap-8 pt-8 border-t border-border">
              <div>
                <div className="text-2xl md:text-3xl font-bold">99.9%</div>
                <div className="text-sm text-muted-foreground">Uptime SLA</div>
              </div>
              <div>
                <div className="text-2xl md:text-3xl font-bold">&lt;100ms</div>
                <div className="text-sm text-muted-foreground">API Response</div>
              </div>
              <div>
                <div className="text-2xl md:text-3xl font-bold">$0.50</div>
                <div className="text-sm text-muted-foreground">Cost/mo per user</div>
              </div>
            </div>
          </div>

          {/* Product Screenshot */}
          <div className="relative">
            <div className="absolute inset-0 bg-gradient-to-br from-primary/20 to-chart-1/20 rounded-2xl blur-3xl" />
            <div className="relative rounded-2xl overflow-hidden border border-border shadow-2xl bg-card">
              <div className="aspect-[4/3] relative">
                <ImageWithFallback
                  src="https://images.unsplash.com/photo-1719464521902-4dc9595b182d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxub3RlcyUyMGFwcCUyMGludGVyZmFjZXxlbnwxfHx8fDE3NjU3MDExMzB8MA&ixlib=rb-4.1.0&q=80&w=1080"
                  alt="Notes app interface showcasing the dashboard and note editor"
                  className="w-full h-full object-cover"
                />
              </div>
              {/* Overlay UI elements for realism */}
              <div className="absolute inset-0 bg-gradient-to-t from-background/80 via-transparent to-transparent" />
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
