export { default } from 'next-auth/middleware'

export const config = {
  matcher: [
    '/dashboard/:path*',
    '/groups/:path*',
    '/friends/:path*',
    '/activity/:path*',
    '/account/:path*',
  ],
}
