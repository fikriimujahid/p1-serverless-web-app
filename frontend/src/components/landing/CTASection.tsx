import React from 'react';
import { ArrowRight, Star } from 'lucide-react';
import { Button } from '../ui/button';
import { AWSLogo, NextJSLogo, TailwindLogo } from './Logos';

interface CTASectionProps {
  onGetStarted: () => void;
}

const testimonials = [
  {
    quote: "The perfect balance of simplicity and power. Deployment was seamless.",
    author: "Sarah Chen",
    role: "Engineering Lead",
    rating: 5,
  },
  {
    quote: "Sub-millisecond response times and costs just pennies per month.",
    author: "Michael Rodriguez",
    role: "CTO",
    rating: 5,
  },
  {
    quote: "AWS Cognito integration saved us weeks of auth implementation.",
    author: "Priya Patel",
    role: "Full Stack Developer",
    rating: 5,
  },
];

export function CTASection({ onGetStarted }: CTASectionProps) {
  return (
    <section className="py-16 md:py-24 bg-gradient-to-br from-accent/30 via-background to-accent/20">
      <div className="container mx-auto px-4 md:px-6 lg:px-8">
        {/* Testimonials */}
        <div className="mb-16">
          <h2 className="text-2xl md:text-3xl font-bold text-center mb-12">
            Loved by Developers
          </h2>
          <div className="grid md:grid-cols-3 gap-6">
            {testimonials.map((testimonial, index) => (
              <div
                key={index}
                className="p-6 rounded-xl bg-card border border-border shadow-sm hover:shadow-md transition-shadow"
              >
                <div className="flex gap-1 mb-4">
                  {Array.from({ length: testimonial.rating }).map((_, i) => (
                    <Star key={i} className="h-4 w-4 fill-primary text-primary" />
                  ))}
                </div>
                <p className="text-muted-foreground mb-4">&quot;{testimonial.quote}&quot;</p>
                <div>
                  <div className="font-semibold">{testimonial.author}</div>
                  <div className="text-sm text-muted-foreground">{testimonial.role}</div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* CTA Box */}
        <div className="relative overflow-hidden rounded-3xl border border-border bg-card p-8 md:p-12 shadow-2xl">
          <div className="absolute inset-0 bg-gradient-to-br from-primary/5 via-transparent to-chart-1/5" />
          
          <div className="relative text-center space-y-6">
            <h2 className="text-3xl md:text-4xl lg:text-5xl font-bold">
              Ready to Get Started?
            </h2>
            <p className="text-lg md:text-xl text-muted-foreground max-w-2xl mx-auto">
              Deploy your own serverless notes app in minutes. Join developers building production-ready apps on AWS.
            </p>

            <div className="flex flex-col sm:flex-row gap-4 justify-center pt-4">
              <Button
                size="lg"
                onClick={onGetStarted}
                className="group text-base md:text-lg px-8 py-6"
              >
                Start Free Trial
                <ArrowRight className="ml-2 h-5 w-5 transition-transform group-hover:translate-x-1" />
              </Button>
              <Button
                size="lg"
                variant="outline"
                onClick={() => window.open('https://github.com', '_blank')}
                className="text-base md:text-lg px-8 py-6"
              >
                View on GitHub
              </Button>
            </div>

            {/* Tech Stack Logos */}
            <div className="pt-8 border-t border-border">
              <p className="text-sm text-muted-foreground mb-6">Powered by industry-leading technologies</p>
              <div className="flex flex-wrap items-center justify-center gap-8 md:gap-12 opacity-60 hover:opacity-100 transition-opacity">
                <AWSLogo className="h-8 md:h-10 w-auto" />
                <NextJSLogo className="h-6 md:h-8 w-auto" />
                <TailwindLogo className="h-6 md:h-8 w-auto" />
              </div>
            </div>

            {/* Trust Indicators */}
            <div className="grid sm:grid-cols-3 gap-6 mt-12 text-center">
              <div>
                <div className="text-2xl md:text-3xl font-bold mb-2">10k+</div>
                <div className="text-sm text-muted-foreground">Active Deployments</div>
              </div>
              <div>
                <div className="text-2xl md:text-3xl font-bold mb-2">99.99%</div>
                <div className="text-sm text-muted-foreground">Success Rate</div>
              </div>
              <div>
                <div className="text-2xl md:text-3xl font-bold mb-2">24/7</div>
                <div className="text-sm text-muted-foreground">AWS Monitoring</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
