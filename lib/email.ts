import { Resend } from 'resend'

const resend = new Resend(process.env.RESEND_API_KEY)

export interface EmailOptions {
  to: string
  subject: string
  html: string
  text?: string
}

export async function sendEmail(options: EmailOptions): Promise<{ success: boolean; error?: string; logged?: boolean }> {
  // If Resend API key is not configured, log the email instead
  if (!process.env.RESEND_API_KEY || process.env.RESEND_API_KEY === 're_xxxxxxxx') {
    console.log('')
    console.log('╔════════════════════════════════════════════════════════════════╗')
    console.log('║  📧 EMAIL (Resend not configured - logging only)              ║')
    console.log('╠════════════════════════════════════════════════════════════════╣')
    console.log(`║  To:      ${options.to.padEnd(52)} ║`)
    console.log(`║  Subject: ${options.subject.padEnd(52)} ║`)
    console.log('╚════════════════════════════════════════════════════════════════╝')
    return { success: true, logged: true }
  }

  try {
    const { data, error } = await resend.emails.send({
      from: process.env.EMAIL_FROM || 'onboarding@resend.dev',
      to: options.to,
      subject: options.subject,
      html: options.html,
      text: options.text,
    })

    if (error) {
      // Handle Resend free tier restriction (can only send to account owner)
      if (error.name === 'validation_error' && error.statusCode === 403) {
        console.log('')
        console.log('╔════════════════════════════════════════════════════════════════╗')
        console.log('║  📧 EMAIL (Resend free tier - logging only)                   ║')
        console.log('╠════════════════════════════════════════════════════════════════╣')
        console.log(`║  To:      ${options.to.padEnd(52)} ║`)
        console.log(`║  Subject: ${options.subject.padEnd(52)} ║`)
        console.log('║                                                                ║')
        console.log('║  ⚠️  Resend free tier only allows sending to your own email    ║')
        console.log('║     To send to any recipient, verify a domain at:              ║')
        console.log('║     https://resend.com/domains                                 ║')
        console.log('╚════════════════════════════════════════════════════════════════╝')
        return { success: true, logged: true }
      }
      
      console.error('Failed to send email:', error)
      return { success: false, error: error.message }
    }

    console.log('📧 Email sent successfully:', data?.id)
    return { success: true }
  } catch (error: any) {
    console.error('Failed to send email:', error)
    return { success: false, error: error.message }
  }
}

export function generateVerificationEmailHtml(token: string, appUrl: string): string {
  const verificationUrl = `${appUrl}/api/auth/verify-email?token=${token}`
  
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Verify your FairShare account</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 600px;
      margin: 0 auto;
      padding: 20px;
    }
    .container {
      background: #ffffff;
      border-radius: 8px;
      padding: 40px;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    }
    .logo {
      text-align: center;
      margin-bottom: 30px;
    }
    .logo-icon {
      width: 48px;
      height: 48px;
      background: #0d9488;
      border-radius: 12px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      color: white;
      font-size: 24px;
      font-weight: bold;
    }
    h1 {
      color: #111827;
      font-size: 24px;
      margin-bottom: 16px;
    }
    p {
      color: #6b7280;
      margin-bottom: 24px;
    }
    .button {
      display: inline-block;
      background: #0d9488;
      color: white;
      text-decoration: none;
      padding: 12px 32px;
      border-radius: 8px;
      font-weight: 600;
    }
    .button:hover {
      background: #0f766e;
    }
    .link {
      word-break: break-all;
      color: #0d9488;
    }
    .footer {
      margin-top: 40px;
      padding-top: 20px;
      border-top: 1px solid #e5e7eb;
      font-size: 12px;
      color: #9ca3af;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="logo">
      <div class="logo-icon">FS</div>
    </div>
    <h1>Verify your email address</h1>
    <p>Thanks for signing up for FairShare! Please click the button below to verify your email address and complete your registration.</p>
    <p style="text-align: center;">
      <a href="${verificationUrl}" class="button">Verify Email</a>
    </p>
    <p>Or copy and paste this link into your browser:</p>
    <p class="link">${verificationUrl}</p>
    <p>This link will expire in 24 hours.</p>
    <div class="footer">
      <p>If you didn't create an account on FairShare, you can safely ignore this email.</p>
      <p>&copy; ${new Date().getFullYear()} FairShare. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
  `
}

export function generateVerificationEmailText(token: string, appUrl: string): string {
  const verificationUrl = `${appUrl}/api/auth/verify-email?token=${token}`
  
  return `Verify your FairShare account

Thanks for signing up for FairShare! Please click the link below to verify your email address:

${verificationUrl}

This link will expire in 24 hours.

If you didn't create an account on FairShare, you can safely ignore this email.

© ${new Date().getFullYear()} FairShare. All rights reserved.
  `
}

export async function sendVerificationEmail(email: string, token: string): Promise<{ success: boolean; error?: string; logged?: boolean }> {
  const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'
  
  return await sendEmail({
    to: email,
    subject: 'Verify your FairShare account',
    html: generateVerificationEmailHtml(token, appUrl),
    text: generateVerificationEmailText(token, appUrl),
  })
}
