# TeleTalker Booking & AI Customization Guide

A friendly guide for setting up your booking page and customizing how your AI assistant talks to customers.

---

## Table of Contents

1. [Setting Up Your Booking Page](#setting-up-your-booking-page)
2. [Customizing Your Booking Page](#customizing-your-booking-page)
3. [How Customers Book Appointments](#how-customers-book-appointments)
4. [What Happens After a Booking](#what-happens-after-a-booking)
5. [Viewing Your Bookings](#viewing-your-bookings)
6. [Customizing the AI for Booking Calls](#customizing-the-ai-for-booking-calls)
7. [Customizing the AI for Incoming Calls](#customizing-the-ai-for-incoming-calls)
8. [Tips & Troubleshooting](#tips--troubleshooting)

---

## Setting Up Your Booking Page

Your TeleTalker app gives you a personal booking page that customers can visit to schedule appointments. Here's how to set it up:

### Step 1: Open Booking Settings

1. Open the **TeleTalker** app on your phone.
2. Go to **Settings** (tap the gear icon).
3. Tap **Booking Page Setup**.

### Step 2: Fill In Your Business Details

You'll see a simple form with these fields:

- **Business Name** — The name customers will see (e.g., "Jeff's Barbershop").
- **Your Link** — A short, unique name for your booking page URL. For example, if you type `jeffs-barbershop`, your page will be at `teletalker-21348.web.app/book/jeffs-barbershop`. Keep it short and simple — no spaces allowed.
- **Timezone** — Select your local timezone so appointment times are shown correctly.

### Step 3: Add Your Services

Tap **+ Add Service** to list what you offer. For each service, enter:

- **Service name** (e.g., "Haircut", "Consultation", "30-min Session")
- **Duration** in minutes (e.g., 30, 60)
- **Price** (optional)

You can add as many services as you need. Tap the trash icon to remove one.

### Step 4: Set Your Working Hours

For each day of the week, set when you're available for bookings. Toggle days on or off, and set your start and end times.

### Step 5: Choose Your AI Agent

Under **AI Agent for Calls**, pick which AI voice will call your customers to confirm their appointments. If you have multiple agents set up in ElevenLabs, you can choose the one you prefer here.

### Step 6: Save

Tap **Save** at the bottom. Your booking page is now live!

---

## Customizing Your Booking Page

### Changing Your Link

You can change your booking link anytime in **Settings → Booking Page Setup**. Just type a new one and save. Note: the old link will stop working immediately.

### Updating Services or Hours

Come back to **Booking Page Setup** anytime to add, remove, or edit services and change your available hours. Changes take effect immediately.

---

## How Customers Book Appointments

Here's what your customers see when they visit your booking page:

### Step 1: They Visit Your Link

Share your booking link with customers however you like — on social media, your website, a business card, or by text. The link looks like:

```
teletalker-21348.web.app/book/your-business-name
```

### Step 2: They Pick a Service

Your booking page shows all the services you've added. The customer taps the one they want.

### Step 3: They Choose a Date and Time

A calendar shows available time slots based on your working hours. Slots that are already booked won't appear — so there's no double-booking.

### Step 4: They Enter Their Details

The customer fills in:

- Their **name**
- Their **phone number** (this is where the AI will call them)
- Any **notes** (optional — e.g., "I'd like a fade cut")

### Step 5: They Confirm

After tapping **Book Appointment**, they see a success message:

> "Your phone will ring shortly for confirmation."

That's it from their side!

---

## What Happens After a Booking

This is where the magic happens:

1. **Within 30–60 seconds**, your TeleTalker device automatically places an AI call to the customer's phone number.
2. The AI greets them by name, mentions the service and time they booked, and asks them to **confirm**, **reschedule**, or **cancel**.
3. Based on their response:
   - **Confirmed** — The booking is locked in. You'll see "Confirmed" in your dashboard.
   - **Rescheduled** — The AI notes the new preferred time. You'll see the updated time in your dashboard.
   - **Cancelled** — The booking is cancelled and the slot opens back up.
   - **No answer** — If the customer doesn't pick up, the booking stays as "Scheduled" and you can re-call them later.

All of this happens automatically. You don't need to do anything — just keep your phone on and the TeleTalker app running.

---

## Viewing Your Bookings

### On Your Phone (Mobile App)

1. Go to **Settings → Booking Page Setup**.
2. Tap **View Bookings** at the bottom.
3. You'll see all your bookings with color-coded status pills:
   - **Scheduled** (blue) — Waiting for the AI to call
   - **Calling now...** (amber) — AI is on the phone with the customer right now
   - **Confirmed** (green) — Customer confirmed
   - **Rescheduled** (purple) — Customer asked for a different time
   - **Cancelled** (red) — Customer cancelled
   - **No answer** (gray) — Customer didn't pick up
   - **Failed** (dark red) — Something went wrong with the call

Each booking also shows an **AI Note** — a short summary of what happened on the call (e.g., "Customer confirmed. They mentioned they'll arrive 5 minutes early.").

### On the Web Dashboard

Log in at `teletalker-21348.web.app/login` with the same email and password you use in the app. The dashboard shows the same booking list with real-time updates — you'll see statuses change live as calls happen.

From the web dashboard you can also:

- **Re-call** a customer if the first call failed or they didn't answer.
- **Mark as failed** if you know a booking isn't going to work out.

---

## Customizing the AI for Booking Calls

You can control how your AI sounds and what it says when calling customers to confirm bookings.

### Where to Find It

**Settings → Booking Page Setup → AI Script & Personality**

### What You Can Customize

#### Tone

Pick how your AI should sound:

- **Warm** — Friendly and welcoming (great for salons, wellness, personal services)
- **Professional** — Polished and business-like (great for consultants, medical offices)
- **Casual** — Relaxed and easygoing (great for creative businesses, food trucks)
- **Friendly** — Upbeat and approachable (great for family businesses)

Just tap the one that fits your brand. The AI adjusts its word choice and speaking style to match.

#### First Message

This is the very first thing the AI says when the customer picks up. You can write your own, or use the default:

> "Hi {customer_name}, this is {business_name} calling to confirm your {service_name} appointment on {appointment_date}."

Notice the **{curly bracket}** placeholders — these get replaced automatically with the real details for each call. Available placeholders:

- `{customer_name}` — The customer's name
- `{business_name}` — Your business name
- `{service_name}` — The service they booked
- `{appointment_date}` — The date and time of their appointment

Tap any placeholder chip below the text box to insert it.

#### Voicemail Message

If the customer doesn't answer and their voicemail picks up, the AI will leave this message instead. Customize it to sound natural and on-brand.

#### Rules

Add specific instructions for your AI. Tap **+ Add rule** and type things like:

- "Always mention our cancellation policy: 24 hours notice required"
- "If they ask about parking, tell them we have free parking behind the building"
- "Never offer discounts"
- "Speak in Arabic if the customer responds in Arabic"

Rules are short, specific instructions that guide the AI's behavior.

#### Advanced: Full Prompt Override

If you're comfortable with it, toggle on **Advanced override** to write the complete system prompt yourself. This replaces everything above (tone, rules, etc.) with your exact instructions. Most users don't need this — the tone + rules approach covers 99% of cases.

---

## Customizing the AI for Incoming Calls

When someone calls your TeleTalker number and the AI receptionist picks up, you can customize how it handles those calls too — and you can set different scripts for different AI agents.

### Where to Find It

**Settings → Inbound AI Receptionist**

### How It Works

#### Pick an Agent

If you have multiple AI agents (voices) set up, pick the one you want to customize from the dropdown at the top. Each agent can have its own personality and script.

#### Tone

Same options as booking calls — Warm, Professional, Casual, or Friendly.

#### First Message

What the AI says when it answers an incoming call. For example:

> "Hi {customer_name}, thanks for calling {business_name}! How can I help you today?"

#### Role / Additional Instructions

Tell the AI what it should do and know. For example:

- "You are the receptionist for Dr. Smith's dental office. You can schedule appointments, answer questions about our services, and take messages."
- "Our office hours are Monday–Friday, 9 AM to 5 PM."
- "If someone asks about pricing, tell them a cleaning starts at $150."

#### Rules

Same as booking calls — short, specific do's and don'ts:

- "Always ask for the caller's name and phone number"
- "If they need emergency service, tell them to call 911"
- "Transfer to a human if they say 'speak to a person'"

#### Activate

Toggle the **Active** switch on and tap **Save**. The AI will now use your custom script for all incoming calls handled by that agent.

---

## Tips & Troubleshooting

### Keep Your Phone On

The AI calls are placed from your phone. Make sure:
- Your phone is **charged and connected to the internet**
- The **TeleTalker app** is running (it can be in the background)
- **Do Not Disturb** is off, or TeleTalker is allowed through it

### Share Your Booking Link

The more places you share your link, the more bookings you'll get:
- Add it to your Instagram/Facebook bio
- Put it on your website
- Print it on business cards with a QR code
- Text it to existing customers

### If a Call Fails

Sometimes calls don't go through (customer's phone is off, bad signal, etc.). You can:
- **Re-call** from the web dashboard
- **Re-call** from the mobile bookings list (coming soon)
- The AI will only try once automatically — you decide if/when to retry

### Customization Takes Effect Immediately

Any changes you make to tone, first message, or rules apply to the very next call. No need to restart anything.

### Multiple Services

You can add as many services as you want. Customers pick one when booking, and the AI mentions it by name on the call.

### Working Hours

If a customer tries to book outside your working hours, those slots simply won't appear. You're always in control of when you're available.

---

## Quick Reference

| What you want to do | Where to go |
|---|---|
| Set up booking page | Settings → Booking Page Setup |
| Add/edit services | Settings → Booking Page Setup → Services |
| Change working hours | Settings → Booking Page Setup → Hours |
| View all bookings | Settings → Booking Page Setup → View Bookings |
| Customize booking call AI | Settings → Booking Page Setup → AI Script |
| Customize inbound call AI | Settings → Inbound AI Receptionist |
| Web dashboard | teletalker-21348.web.app/login |
| Your booking page | teletalker-21348.web.app/book/your-link |

---

