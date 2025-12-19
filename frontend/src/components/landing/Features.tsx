import React from 'react';
import { Cloud, Wifi, Shield, Search, DollarSign } from 'lucide-react';
import { Card, CardContent } from '../ui/card';

const features = [
  {
    icon: Cloud,
    title: 'Serverless & Scalable',
    description: 'Built on AWS Lambda and DynamoDB. Auto-scales from zero to millions of users without infrastructure management.',
    badge: 'AWS-Powered',
  },
  {
    icon: Wifi,
    title: 'Offline-Friendly',
    description: 'Work seamlessly offline with automatic sync. Your notes are cached locally and sync when you reconnect.',
    badge: 'PWA Ready',
  },
  {
    icon: Shield,
    title: 'Secure with Cognito',
    description: 'Enterprise-grade authentication with AWS Cognito. MFA, OAuth, and SAML support out of the box.',
    badge: 'SOC 2 Compliant',
  },
  {
    icon: Search,
    title: 'Fast Search',
    description: 'Find anything instantly with full-text search powered by DynamoDB queries and client-side indexing.',
    badge: 'Sub-50ms',
  },
  {
    icon: DollarSign,
    title: 'Cost-Effective',
    description: 'Pay only for what you use. Typical costs: $0.50/user/month with AWS Free Tier covering first 1M requests.',
    badge: 'Free Tier',
  },
];

export function Features() {
  return (
    <section className="py-16 md:py-24 bg-background" id="features">
      <div className="container mx-auto px-4 md:px-6 lg:px-8">
        <div className="text-center mb-12 md:mb-16">
          <div className="inline-block px-3 py-1 mb-4 rounded-full bg-accent text-accent-foreground text-sm">
            Features
          </div>
          <h2 className="text-3xl md:text-4xl lg:text-5xl font-bold mb-4">
            Everything You Need
          </h2>
          <p className="text-lg text-muted-foreground max-w-2xl mx-auto">
            Production-ready features built on enterprise-grade AWS services
          </p>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6 md:gap-8">
          {features.map((feature, index) => {
            const Icon = feature.icon;
            return (
              <Card
                key={index}
                className="group relative overflow-hidden transition-all duration-300 hover:shadow-lg hover:-translate-y-1 border-border"
              >
                <CardContent className="p-6 md:p-8">
                  <div className="flex items-start justify-between mb-4">
                    <div className="p-3 rounded-xl bg-accent group-hover:bg-primary group-hover:text-primary-foreground transition-colors">
                      <Icon className="h-6 w-6" />
                    </div>
                    <span className="px-2 py-1 text-xs rounded-full bg-accent text-accent-foreground border border-border">
                      {feature.badge}
                    </span>
                  </div>
                  <h3 className="text-xl font-semibold mb-2">{feature.title}</h3>
                  <p className="text-muted-foreground">{feature.description}</p>
                </CardContent>
                {/* Hover gradient effect */}
                <div className="absolute inset-0 bg-gradient-to-br from-primary/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none" />
              </Card>
            );
          })}
        </div>

        {/* Cost Breakdown */}
        <div className="mt-12 md:mt-16 p-6 md:p-8 rounded-2xl border border-border bg-card">
          <h3 className="text-xl md:text-2xl font-semibold mb-4 text-center">Monthly Cost Estimate</h3>
          <div className="grid sm:grid-cols-2 md:grid-cols-4 gap-6 text-center">
            <div>
              <div className="text-3xl font-bold text-primary">$0.05</div>
              <div className="text-sm text-muted-foreground mt-1">Lambda Executions</div>
              <div className="text-xs text-muted-foreground mt-1">~100k requests</div>
            </div>
            <div>
              <div className="text-3xl font-bold text-primary">$0.25</div>
              <div className="text-sm text-muted-foreground mt-1">DynamoDB Storage</div>
              <div className="text-xs text-muted-foreground mt-1">~1GB data</div>
            </div>
            <div>
              <div className="text-3xl font-bold text-primary">$0.10</div>
              <div className="text-sm text-muted-foreground mt-1">CloudFront CDN</div>
              <div className="text-xs text-muted-foreground mt-1">~50GB transfer</div>
            </div>
            <div>
              <div className="text-3xl font-bold text-primary">$0.10</div>
              <div className="text-sm text-muted-foreground mt-1">API Gateway</div>
              <div className="text-xs text-muted-foreground mt-1">~100k calls</div>
            </div>
          </div>
          <p className="text-center text-sm text-muted-foreground mt-6">
            * Estimates based on typical usage. AWS Free Tier covers most of these costs for the first year.
          </p>
        </div>
      </div>
    </section>
  );
}
