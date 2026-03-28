"""
CEREBRO - Email Utility
Sends emails via Gmail SMTP using App Passwords.

Setup:
  1. Go to https://myaccount.google.com/security
  2. Enable 2-Step Verification (required for App Passwords)
  3. Go to https://myaccount.google.com/apppasswords
  4. Create an App Password for "Mail" → "Other (Cerebro)"
  5. Copy the 16-character password (spaces don't matter)
  6. Set SMTP_USER and SMTP_PASSWORD in your .env file
"""

import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from app.config import settings


def send_email(to_email: str, subject: str, html_body: str) -> bool:
    """
    Send an HTML email via SMTP.
    Returns True on success, False on failure.
    """
    if not settings.SMTP_USER or not settings.SMTP_PASSWORD:
        print(f"[EMAIL] SMTP not configured — skipping email to {to_email}")
        print(f"[EMAIL] Subject: {subject}")
        return False

    msg = MIMEMultipart("alternative")
    msg["From"] = f"{settings.SMTP_FROM_NAME} <{settings.SMTP_USER}>"
    msg["To"] = to_email
    msg["Subject"] = subject

    # Plain text fallback
    plain_text = html_body.replace("<br>", "\n").replace("<br/>", "\n")
    import re
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


def send_event_reminder_email(
    to_email: str,
    *,
    display_name: str,
    event_title: str,
    event_when: str,
    event_topic: str = "",
) -> bool:
    """Send a day-before event reminder email.

    Mirrors the visual language of `send_reset_code_email` (same cream
    body + dark border + pink header + sage footer) so reminders feel
    like part of the same product family. Called from the notifications
    router when the user has `daily_reminders_enabled = True`.
    """

    subject = f"Cerebro — Reminder: {event_title} is tomorrow"

    topic_block = ""
    if event_topic:
        topic_block = f"""
        <p style=\"color: #4d5a3a; font-size: 14px; line-height: 1.6; margin: 0 0 8px;\">
          <strong>Topic:</strong> {event_topic}
        </p>
        """

    html_body = f"""
    <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 480px; margin: 0 auto; background: #fdefdb; border-radius: 18px; border: 3px solid #2c3322; overflow: hidden;">
      <!-- Header -->
      <div style="background: #fea9d3; padding: 28px 32px; border-bottom: 3px solid #2c3322;">
        <h1 style="margin: 0; font-size: 28px; color: #2c3322; font-weight: bold;">Cerebro.</h1>
        <p style="margin: 6px 0 0; color: #4d5a3a; font-size: 14px;">You have something coming up tomorrow</p>
      </div>

      <!-- Body -->
      <div style="padding: 32px;">
        <p style="color: #2c3322; font-size: 16px; margin: 0 0 16px;">
          Hey {display_name},
        </p>
        <p style="color: #4d5a3a; font-size: 14px; line-height: 1.6; margin: 0 0 20px;">
          Just a heads up — this is on your schedule for tomorrow:
        </p>

        <!-- Event Box -->
        <div style="background: white; border: 3px solid #2c3322; border-radius: 14px; padding: 20px; margin: 0 0 20px; box-shadow: 4px 4px 0 #2c3322;">
          <p style="margin: 0 0 6px; color: #2c3322; font-size: 20px; font-weight: 800;">
            {event_title}
          </p>
          <p style="margin: 0; color: #8a9668; font-size: 14px; font-weight: 600;">
            {event_when}
          </p>
        </div>

        {topic_block}

        <p style="color: #8a9668; font-size: 13px; line-height: 1.5; margin: 0 0 8px;">
          Open Cerebro to review or reschedule.
        </p>
        <p style="color: #8a9668; font-size: 13px; line-height: 1.5; margin: 0;">
          You can turn off Daily Reminders any time in Profile → Settings.
        </p>
      </div>

      <!-- Footer -->
      <div style="background: #58772f; padding: 18px 32px; text-align: center;">
        <p style="margin: 0; color: #f9fdec; font-size: 12px;">
          Cerebro — Your smart student companion
        </p>
      </div>
    </div>
    """

    return send_email(to_email, subject, html_body)


def send_reset_code_email(to_email: str, reset_code: str, display_name: str = "there") -> bool:
    """Send a password reset code email with Cerebro branding."""

    subject = f"Cerebro — Your password reset code is {reset_code}"

    html_body = f"""
    <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 480px; margin: 0 auto; background: #fdefdb; border-radius: 18px; border: 3px solid #2c3322; overflow: hidden;">
      <!-- Header -->
      <div style="background: #fea9d3; padding: 28px 32px; border-bottom: 3px solid #2c3322;">
        <h1 style="margin: 0; font-size: 28px; color: #2c3322; font-weight: bold;">Cerebro.</h1>
        <p style="margin: 6px 0 0; color: #4d5a3a; font-size: 14px;">Password Reset Request</p>
      </div>

      <!-- Body -->
      <div style="padding: 32px;">
        <p style="color: #2c3322; font-size: 16px; margin: 0 0 16px;">
          Hey {display_name},
        </p>
        <p style="color: #4d5a3a; font-size: 14px; line-height: 1.6; margin: 0 0 24px;">
          We received a request to reset your password. Use this 6-digit code to set a new one:
        </p>

        <!-- Code Box -->
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

      <!-- Footer -->
      <div style="background: #58772f; padding: 18px 32px; text-align: center;">
        <p style="margin: 0; color: #f9fdec; font-size: 12px;">
          Cerebro — Your smart student companion
        </p>
      </div>
    </div>
    """

    return send_email(to_email, subject, html_body)
