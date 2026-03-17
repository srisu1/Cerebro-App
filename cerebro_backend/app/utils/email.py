import smtplib
import re
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from app.config import settings


def send_email(to_email: str, subject: str, html_body: str) -> bool:
    if not settings.SMTP_USER or not settings.SMTP_PASSWORD:
        print(f"[EMAIL] SMTP not configured — skipping email to {to_email}")
        print(f"[EMAIL] Subject: {subject}")
        return False

    msg = MIMEMultipart("alternative")
    msg["From"] = f"{settings.SMTP_FROM_NAME} <{settings.SMTP_USER}>"
    msg["To"] = to_email
    msg["Subject"] = subject

    plain_text = html_body.replace("<br>", "\n").replace("<br/>", "\n")
    plain_text = re.sub(r"<[^>]+>", "", plain_text)

    msg.attach(MIMEText(plain_text, "plain"))
    msg.attach(MIMEText(html_body, "html"))

    try:
        with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT) as server:
            server.starttls()
            server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
            server.send_message(msg)

        print(f"[EMAIL] Sent to {to_email}: {subject}")
        return True

    except Exception as e:
        print(f"[EMAIL] Failed to send to {to_email}: {e}")
        return False


def send_reset_code_email(to_email: str, reset_code: str, display_name: str = "there") -> bool:
    subject = f"Cerebro — Your password reset code is {reset_code}"

    html_body = f"""
    <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 480px; margin: 0 auto; background: #fdefdb; border-radius: 18px; border: 3px solid #2c3322; overflow: hidden;">
      <div style="background: #fea9d3; padding: 28px 32px; border-bottom: 3px solid #2c3322;">
        <h1 style="margin: 0; font-size: 28px; color: #2c3322; font-weight: bold;">Cerebro.</h1>
        <p style="margin: 6px 0 0; color: #4d5a3a; font-size: 14px;">Password Reset Request</p>
      </div>

      <div style="padding: 32px;">
        <p style="color: #2c3322; font-size: 16px; margin: 0 0 16px;">
          Hey {display_name},
        </p>
        <p style="color: #4d5a3a; font-size: 14px; line-height: 1.6; margin: 0 0 24px;">
          We received a request to reset your password. Use this 6-digit code to set a new one:
        </p>

        <div style="background: white; border: 3px solid #2c3322; border-radius: 14px; padding: 20px; text-align: center; margin: 0 0 24px; box-shadow: 4px 4px 0 #2c3322;">
          <span style="font-size: 36px; font-weight: 800; letter-spacing: 10px; color: #2c3322;">
            {reset_code}
          </span>
        </div>

        <p style="color: #8a9668; font-size: 13px; line-height: 1.5; margin: 0 0 8px;">
          This code expires in <strong>15 minutes</strong>.
        </p>
        <p style="color: #8a9668; font-size: 13px; line-height: 1.5; margin: 0;">
          If you didn't request this, you can safely ignore this email.
        </p>
      </div>

      <div style="background: #58772f; padding: 18px 32px; text-align: center;">
        <p style="margin: 0; color: #f9fdec; font-size: 12px;">
          Cerebro — Your student companion
        </p>
      </div>
    </div>
    """

    return send_email(to_email, subject, html_body)
