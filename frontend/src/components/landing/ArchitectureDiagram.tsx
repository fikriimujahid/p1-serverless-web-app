import React from 'react';

export function ArchitectureDiagram() {
  return (
    <svg
      viewBox="0 0 800 300"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className="w-full h-auto"
      aria-label="Architecture diagram showing CloudFront, S3, API Gateway, Lambda, DynamoDB, and Cognito"
    >
      <defs>
        <linearGradient id="gradient1" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" className="[stop-color:rgb(var(--color-primary))]" />
          <stop offset="100%" className="[stop-color:rgb(var(--color-chart-1))]" />
        </linearGradient>
      </defs>

      {/* Connection Lines */}
      <path
        d="M 130 150 L 190 150"
        stroke="currentColor"
        strokeWidth="2"
        className="text-muted-foreground"
        strokeDasharray="5,5"
      />
      <path
        d="M 290 150 L 350 150"
        stroke="currentColor"
        strokeWidth="2"
        className="text-muted-foreground"
        strokeDasharray="5,5"
      />
      <path
        d="M 450 150 L 510 150"
        stroke="currentColor"
        strokeWidth="2"
        className="text-muted-foreground"
        strokeDasharray="5,5"
      />
      <path
        d="M 610 150 L 670 150"
        stroke="currentColor"
        strokeWidth="2"
        className="text-muted-foreground"
        strokeDasharray="5,5"
      />
      <path
        d="M 560 90 L 560 130"
        stroke="currentColor"
        strokeWidth="2"
        className="text-muted-foreground"
        strokeDasharray="5,5"
      />

      {/* CloudFront */}
      <g>
        <rect x="30" y="120" width="100" height="60" rx="8" className="fill-card stroke-border" strokeWidth="2" />
        <text x="80" y="145" textAnchor="middle" className="fill-foreground text-sm font-medium">CloudFront</text>
        <text x="80" y="165" textAnchor="middle" className="fill-muted-foreground text-xs">CDN</text>
      </g>

      {/* S3 */}
      <g>
        <rect x="190" y="120" width="100" height="60" rx="8" className="fill-card stroke-border" strokeWidth="2" />
        <text x="240" y="145" textAnchor="middle" className="fill-foreground text-sm font-medium">S3</text>
        <text x="240" y="165" textAnchor="middle" className="fill-muted-foreground text-xs">Storage</text>
      </g>

      {/* API Gateway */}
      <g>
        <rect x="350" y="120" width="100" height="60" rx="8" className="fill-card stroke-border" strokeWidth="2" />
        <text x="400" y="140" textAnchor="middle" className="fill-foreground text-sm font-medium">API</text>
        <text x="400" y="155" textAnchor="middle" className="fill-foreground text-sm font-medium">Gateway</text>
        <text x="400" y="170" textAnchor="middle" className="fill-muted-foreground text-xs">REST API</text>
      </g>

      {/* Lambda */}
      <g>
        <rect x="510" y="120" width="100" height="60" rx="8" className="fill-card stroke-border" strokeWidth="2" />
        <text x="560" y="145" textAnchor="middle" className="fill-foreground text-sm font-medium">Lambda</text>
        <text x="560" y="165" textAnchor="middle" className="fill-muted-foreground text-xs">Functions</text>
      </g>

      {/* DynamoDB */}
      <g>
        <rect x="670" y="120" width="100" height="60" rx="8" className="fill-card stroke-border" strokeWidth="2" />
        <text x="720" y="145" textAnchor="middle" className="fill-foreground text-sm font-medium">DynamoDB</text>
        <text x="720" y="165" textAnchor="middle" className="fill-muted-foreground text-xs">Database</text>
      </g>

      {/* Cognito */}
      <g>
        <rect x="510" y="30" width="100" height="60" rx="8" className="fill-card stroke-border" strokeWidth="2" />
        <text x="560" y="55" textAnchor="middle" className="fill-foreground text-sm font-medium">Cognito</text>
        <text x="560" y="75" textAnchor="middle" className="fill-muted-foreground text-xs">Auth</text>
      </g>

      {/* Arrows */}
      <polygon points="185,150 190,147 190,153" className="fill-muted-foreground" />
      <polygon points="345,150 350,147 350,153" className="fill-muted-foreground" />
      <polygon points="505,150 510,147 510,153" className="fill-muted-foreground" />
      <polygon points="665,150 670,147 670,153" className="fill-muted-foreground" />
      <polygon points="560,125 557,130 563,130" className="fill-muted-foreground" />
    </svg>
  );
}
