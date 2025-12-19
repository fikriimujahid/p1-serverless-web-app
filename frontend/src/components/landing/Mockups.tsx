import React from 'react';
import { ImageWithFallback } from '../ImageWithFallback';

export function Mockups() {
  return (
    <section className="py-16 md:py-24 bg-background" id="mockups">
      <div className="container mx-auto px-4 md:px-6 lg:px-8">
        <div className="text-center mb-12 md:mb-16">
          <div className="inline-block px-3 py-1 mb-4 rounded-full bg-accent text-accent-foreground text-sm">
            Experience
          </div>
          <h2 className="text-3xl md:text-4xl lg:text-5xl font-bold mb-4">
            Seamless Across Devices
          </h2>
          <p className="text-lg text-muted-foreground max-w-2xl mx-auto">
            Responsive design that works perfectly on desktop, tablet, and mobile
          </p>
        </div>

        <div className="grid md:grid-cols-3 gap-8">
          {/* Notes List */}
          <div className="space-y-4">
            <div className="relative group">
              <div className="absolute -inset-1 bg-gradient-to-br from-primary/20 to-chart-1/20 rounded-2xl blur-xl opacity-0 group-hover:opacity-100 transition-opacity" />
              <div className="relative bg-card rounded-2xl border border-border overflow-hidden shadow-lg">
                <div className="aspect-[3/4] relative">
                  <ImageWithFallback
                    src="https://images.unsplash.com/photo-1691725909676-105654d24649?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxkYXNoYm9hcmQlMjBpbnRlcmZhY2V8ZW58MXx8fHwxNzY1NjcxNTcwfDA&ixlib=rb-4.1.0&q=80&w=1080"
                    alt="Notes list view showing all your notes organized by date"
                    className="w-full h-full object-cover"
                  />
                </div>
                <div className="absolute inset-0 bg-gradient-to-t from-background/90 via-transparent to-transparent" />
                <div className="absolute bottom-4 left-4 right-4">
                  <div className="inline-block px-2 py-1 rounded bg-background/80 backdrop-blur-sm border border-border text-xs mb-2">
                    Desktop
                  </div>
                  <h3 className="font-semibold text-lg">Notes List</h3>
                  <p className="text-sm text-muted-foreground">Organize and search all your notes</p>
                </div>
              </div>
            </div>
          </div>

          {/* Editor */}
          <div className="space-y-4">
            <div className="relative group">
              <div className="absolute -inset-1 bg-gradient-to-br from-chart-2/20 to-chart-3/20 rounded-2xl blur-xl opacity-0 group-hover:opacity-100 transition-opacity" />
              <div className="relative bg-card rounded-2xl border border-border overflow-hidden shadow-lg">
                <div className="aspect-[3/4] relative">
                  <ImageWithFallback
                    src="https://images.unsplash.com/photo-1719464521902-4dc9595b182d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxub3RlcyUyMGFwcCUyMGludGVyZmFjZXxlbnwxfHx8fDE3NjU3MDExMzB8MA&ixlib=rb-4.1.0&q=80&w=1080"
                    alt="Note editor with rich text formatting and real-time sync"
                    className="w-full h-full object-cover"
                  />
                </div>
                <div className="absolute inset-0 bg-gradient-to-t from-background/90 via-transparent to-transparent" />
                <div className="absolute bottom-4 left-4 right-4">
                  <div className="inline-block px-2 py-1 rounded bg-background/80 backdrop-blur-sm border border-border text-xs mb-2">
                    Tablet
                  </div>
                  <h3 className="font-semibold text-lg">Rich Editor</h3>
                  <p className="text-sm text-muted-foreground">Write with markdown support</p>
                </div>
              </div>
            </div>
          </div>

          {/* Auth Flow */}
          <div className="space-y-4">
            <div className="relative group">
              <div className="absolute -inset-1 bg-gradient-to-br from-chart-4/20 to-chart-5/20 rounded-2xl blur-xl opacity-0 group-hover:opacity-100 transition-opacity" />
              <div className="relative bg-card rounded-2xl border border-border overflow-hidden shadow-lg">
                <div className="aspect-[3/4] relative">
                  <ImageWithFallback
                    src="https://images.unsplash.com/photo-1614020661483-d2bb855eee1d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxtb2JpbGUlMjBhcHAlMjBzY3JlZW58ZW58MXx8fHwxNzY1NjM3NTIyfDA&ixlib=rb-4.1.0&q=80&w=1080"
                    alt="Secure authentication flow with AWS Cognito"
                    className="w-full h-full object-cover"
                  />
                </div>
                <div className="absolute inset-0 bg-gradient-to-t from-background/90 via-transparent to-transparent" />
                <div className="absolute bottom-4 left-4 right-4">
                  <div className="inline-block px-2 py-1 rounded bg-background/80 backdrop-blur-sm border border-border text-xs mb-2">
                    Mobile
                  </div>
                  <h3 className="font-semibold text-lg">Secure Auth</h3>
                  <p className="text-sm text-muted-foreground">AWS Cognito authentication</p>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Feature Highlights */}
        <div className="grid sm:grid-cols-2 md:grid-cols-4 gap-4 mt-12 md:mt-16">
          <div className="p-4 rounded-xl border border-border bg-card text-center">
            <div className="text-2xl font-bold text-primary mb-1">100%</div>
            <div className="text-sm text-muted-foreground">Responsive</div>
          </div>
          <div className="p-4 rounded-xl border border-border bg-card text-center">
            <div className="text-2xl font-bold text-primary mb-1">WCAG AA</div>
            <div className="text-sm text-muted-foreground">Accessible</div>
          </div>
          <div className="p-4 rounded-xl border border-border bg-card text-center">
            <div className="text-2xl font-bold text-primary mb-1">Dark Mode</div>
            <div className="text-sm text-muted-foreground">Theme Support</div>
          </div>
          <div className="p-4 rounded-xl border border-border bg-card text-center">
            <div className="text-2xl font-bold text-primary mb-1">PWA</div>
            <div className="text-sm text-muted-foreground">Install Ready</div>
          </div>
        </div>
      </div>
    </section>
  );
}
