import React from 'react';
import { ArchitectureDiagram } from './ArchitectureDiagram';

export function Architecture() {
  return (
    <section className="py-16 md:py-24 bg-accent/30" id="architecture">
      <div className="container mx-auto px-4 md:px-6 lg:px-8">
        <div className="text-center mb-12 md:mb-16">
          <div className="inline-block px-3 py-1 mb-4 rounded-full bg-accent text-accent-foreground text-sm border border-border">
            Architecture
          </div>
          <h2 className="text-3xl md:text-4xl lg:text-5xl font-bold mb-4">
            Built on AWS
          </h2>
          <p className="text-lg text-muted-foreground max-w-2xl mx-auto">
            Enterprise-grade serverless architecture that scales automatically
          </p>
        </div>

        <div className="max-w-5xl mx-auto">
          <div className="bg-card rounded-2xl border border-border p-6 md:p-12 shadow-lg">
            <ArchitectureDiagram />
          </div>

          {/* Architecture Details */}
          <div className="grid md:grid-cols-3 gap-6 mt-8">
            <div className="p-6 rounded-xl bg-card border border-border">
              <h3 className="font-semibold mb-2">Frontend Layer</h3>
              <p className="text-sm text-muted-foreground">
                Next.js 14 app deployed to S3, served globally via CloudFront CDN for &lt;50ms latency.
              </p>
            </div>
            <div className="p-6 rounded-xl bg-card border border-border">
              <h3 className="font-semibold mb-2">API Layer</h3>
              <p className="text-sm text-muted-foreground">
                API Gateway routes requests to Lambda functions with automatic scaling and pay-per-use pricing.
              </p>
            </div>
            <div className="p-6 rounded-xl bg-card border border-border">
              <h3 className="font-semibold mb-2">Data Layer</h3>
              <p className="text-sm text-muted-foreground">
                DynamoDB provides single-digit millisecond performance at any scale with automatic backups.
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
