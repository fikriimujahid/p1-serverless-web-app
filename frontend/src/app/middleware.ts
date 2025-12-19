import { NextRequest, NextResponse } from 'next/server';

const publicPages = ['/', '/signup'];
const protectedPages = ['/notes', '/settings'];

export function middleware(request: NextRequest) {
  const token = request.cookies.get('idToken')?.value;

  // Check if protected route
  const isProtectedPage = protectedPages.some((page) =>
    request.nextUrl.pathname.startsWith(page)
  );

  if (isProtectedPage && !token) {
    // Redirect to login if accessing protected route without token
    return NextResponse.redirect(new URL('/', request.url));
  }

  // Redirect to notes if already logged in
  if (publicPages.includes(request.nextUrl.pathname) && token) {
    return NextResponse.redirect(new URL('/notes', request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!api|_next|static|public).*)'],
};