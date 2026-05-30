from django.core.mail import EmailMultiAlternatives
from django.conf import settings
import logging

logger = logging.getLogger('users.otp')


def send_otp_email(to_email, otp_code):
    """Send a 6-digit OTP verification code via email."""
    subject = "[ProductiveAI] Authentication Verification Code"

    html_content = f"""
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Verification Code — ProductiveAI</title>
  <style>
    body {{
      background-color: #050816;
      color: #cbd5e1;
      font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      margin: 0;
      padding: 0;
    }}
    .wrapper {{
      background-color: #050816;
      padding: 40px 20px;
    }}
    .container {{
      max-width: 580px;
      margin: 0 auto;
      background-color: #0d1126;
      border: 1px solid rgba(139, 92, 246, 0.3);
      border-radius: 20px;
      padding: 40px;
      box-shadow: 0 0 30px rgba(139, 92, 246, 0.15);
    }}
    .header {{
      text-align: center;
      margin-bottom: 30px;
    }}
    .logo {{
      display: inline-block;
      background: linear-gradient(135deg, #3b82f6, #8b5cf6);
      color: #ffffff;
      padding: 10px 20px;
      border-radius: 12px;
      font-weight: bold;
      font-size: 1.2rem;
      letter-spacing: 1px;
      box-shadow: 0 0 15px rgba(139, 92, 246, 0.4);
    }}
    h1 {{
      color: #ffffff;
      font-size: 1.5rem;
      font-weight: 800;
      margin-top: 20px;
      text-align: center;
    }}
    p {{
      line-height: 1.6;
      font-size: 0.95rem;
      color: #94a3b8;
    }}
    .otp-container {{
      text-align: center;
      margin: 35px 0;
    }}
    .otp-code {{
      display: inline-block;
      padding: 18px 40px;
      background: linear-gradient(135deg, rgba(59, 130, 246, 0.15), rgba(139, 92, 246, 0.15));
      border: 2px solid rgba(139, 92, 246, 0.4);
      border-radius: 16px;
      font-family: 'Courier New', monospace;
      font-size: 2.5rem;
      font-weight: bold;
      letter-spacing: 12px;
      color: #ffffff;
      box-shadow: 0 0 30px rgba(139, 92, 246, 0.2);
    }}
    .warning {{
      background-color: rgba(239, 68, 68, 0.08);
      border: 1px solid rgba(239, 68, 68, 0.2);
      border-radius: 12px;
      padding: 15px;
      margin-top: 30px;
      font-size: 0.85rem;
      color: #f87171;
    }}
    .info {{
      background-color: rgba(59, 130, 246, 0.08);
      border: 1px solid rgba(59, 130, 246, 0.2);
      border-radius: 12px;
      padding: 15px;
      margin-top: 15px;
      font-size: 0.85rem;
      color: #60a5fa;
    }}
    .footer {{
      text-align: center;
      margin-top: 40px;
      font-size: 0.8rem;
      color: #475569;
      border-top: 1px solid rgba(255, 255, 255, 0.05);
      padding-top: 20px;
    }}
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="container">
      <div class="header">
        <div class="logo">ProductiveAI</div>
      </div>
      <h1>Authentication Verification Code</h1>
      <p>Hello Operator,</p>
      <p>A verification sequence has been initiated for your account. Use the authentication code below to complete the security validation protocol:</p>
      <div class="otp-container">
        <div class="otp-code">{otp_code}</div>
      </div>
      <div class="info">
        <strong> TIME-SENSITIVE:</strong> This authentication code will expire in <strong>10 minutes</strong>.
      </div>
      <div class="warning">
        <strong> SECURITY PROTOCOL:</strong> Do not share this code with anyone. ProductiveAI staff will never ask for your verification code.
      </div>
      <div class="footer">
        ProductiveAI Mainframe Secure AI Productivity Environment<br>
        This is an automated notification. Do not reply directly.
      </div>
    </div>
  </div>
</body>
</html>
"""
    text_content = f"""
ProductiveAI
Authentication Verification Code

Hello Operator,

A verification sequence has been initiated for your account.
Your authentication code is:

    {otp_code}

This code expires in 10 minutes.
Do not share this code with anyone.

ProductiveAI Mainframe Secure AI Productivity Environment
"""

    from_email = settings.DEFAULT_FROM_EMAIL

    msg = EmailMultiAlternatives(subject, text_content, from_email, [to_email])
    msg.attach_alternative(html_content, "text/html")
    msg.send()
    logger.info('[OTP] Sent verification code to %s', to_email)



def send_password_reset_email(to_email, reset_url):
    subject = "[ProductiveAI] Initialize Decryption Key Override"
    
    html_content = f"""
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Reset Your Access Key — ProductiveAI</title>
  <style>
    body {{
      background-color: #050816;
      color: #cbd5e1;
      font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      margin: 0;
      padding: 0;
    }}
    .wrapper {{
      background-color: #050816;
      padding: 40px 20px;
    }}
    .container {{
      max-width: 580px;
      margin: 0 auto;
      background-color: #0d1126;
      border: 1px solid rgba(139, 92, 246, 0.3);
      border-radius: 20px;
      padding: 40px;
      box-shadow: 0 0 30px rgba(139, 92, 246, 0.15);
    }}
    .header {{
      text-align: center;
      margin-bottom: 30px;
    }}
    .logo {{
      display: inline-block;
      background: linear-gradient(135deg, #3b82f6, #8b5cf6);
      color: #ffffff;
      padding: 10px 20px;
      border-radius: 12px;
      font-weight: bold;
      font-size: 1.2rem;
      letter-spacing: 1px;
      box-shadow: 0 0 15px rgba(139, 92, 246, 0.4);
    }}
    h1 {{
      color: #ffffff;
      font-size: 1.5rem;
      font-weight: 800;
      margin-top: 20px;
      text-align: center;
    }}
    p {{
      line-height: 1.6;
      font-size: 0.95rem;
      color: #94a3b8;
    }}
    .cta-container {{
      text-align: center;
      margin: 35px 0;
    }}
    .btn {{
      display: inline-block;
      padding: 14px 30px;
      background: linear-gradient(135deg, #3b82f6, #8b5cf6);
      color: #ffffff !important;
      text-decoration: none;
      font-weight: bold;
      font-size: 0.95rem;
      border-radius: 12px;
      box-shadow: 0 0 20px rgba(139, 92, 246, 0.4);
      transition: all 0.3s ease;
    }}
    .btn:hover {{
      box-shadow: 0 0 30px rgba(139, 92, 246, 0.6);
      transform: translateY(-2px);
    }}
    .warning {{
      background-color: rgba(239, 68, 68, 0.08);
      border: 1px solid rgba(239, 68, 68, 0.2);
      border-radius: 12px;
      padding: 15px;
      margin-top: 30px;
      font-size: 0.85rem;
      color: #f87171;
    }}
    .footer {{
      text-align: center;
      margin-top: 40px;
      font-size: 0.8rem;
      color: #475569;
      border-top: 1px solid rgba(255, 255, 255, 0.05);
      padding-top: 20px;
    }}
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="container">
      <div class="header">
        <div class="logo">ProductiveAI</div>
      </div>
      <h1>Initialize Decryption Key Override</h1>
      <p>Hello Operator,</p>
      <p>We received a request to bypass your account key. A temporary override sequence has been generated. To complete the authentication sequence and register a new security key, execute the protocol link below:</p>
      <div class="cta-container">
        <a class="btn" href="{reset_url}" target="_blank">Reset Authentication Key</a>
      </div>
      <p>If the button above does not work, copy and paste this URL into your browser:</p>
      <p style="word-break: break-all; color: #3b82f6; font-family: monospace; font-size: 0.85rem;">{reset_url}</p>
      <div class="warning">
        <strong>CRITICAL SAFETY PROTOCOL:</strong> This override sequence is highly time-sensitive and will expire in 2 hours. If you did not trigger this protocol, immediately disregard it and contact system command.
      </div>
      <div class="footer">
        ProductiveAI Mainframe • Secure AI Productivity Environment<br>
        This is an automated notification. Do not reply directly.
      </div>
    </div>
  </div>
</body>
</html>
"""
    text_content = f"""
ProductiveAI
Initialize Decryption Key Override

Hello Operator,

We received a request to bypass your account key. A temporary override sequence has been generated.
To complete the authentication sequence and register a new security key, copy and paste this URL into your browser:

{reset_url}

CRITICAL SAFETY PROTOCOL: This override sequence is highly time-sensitive and will expire in 2 hours. If you did not trigger this protocol, immediately disregard it and contact system command.

ProductiveAI Mainframe • Secure AI Productivity Environment
"""
    
    from_email = settings.DEFAULT_FROM_EMAIL
    
    msg = EmailMultiAlternatives(subject, text_content, from_email, [to_email])
    msg.attach_alternative(html_content, "text/html")
    msg.send()
