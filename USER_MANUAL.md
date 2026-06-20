# Parcel Tracker — User Manual v1.0.9

A mobile app for managing parcel delivery operations. Multi-user, offline-first, with OTP collection codes and real-time sync to Business Central.

---

## Table of Contents
1. [Getting Started](#getting-started)
2. [Understanding the Dashboard](#understanding-the-dashboard)
3. [Creating a Parcel](#creating-a-parcel)
4. [Making Payments](#making-payments)
5. [Batches & Dispatching](#batches--dispatching)
6. [In Transit — Tracking Shipments](#in-transit--tracking-shipments)
7. [Receiving & OTP Codes](#receiving--otp-codes)
8. [Collecting Parcels (OTP Verification)](#collecting-parcels-otp-verification)
9. [Printing Receipts](#printing-receipts)
10. [Reports & Analytics](#reports--analytics)
11. [Settings & User Management](#settings--user-management)
12. [Sync, Offline & Auto-Update](#sync-offline--auto-update)
13. [Troubleshooting](#troubleshooting)

---

## Getting Started

### Installation
Download from: `https://nav.trimline.co.ke:4013/ParcelApp/ParcelApp.apk`  
Requires Android 7.0+. Allow "Install from unknown sources" if prompted.

### Login Screen
1. Enter your **Agent Code** (provided by your administrator)
2. Enter your **Password**
3. Toggle **Remember Me** to save credentials
4. Tap **Sign In**

After login, the top bar shows: `YOUR NAME | YOUR LOCATION`

---

## Understanding the Dashboard

### Summary Bar (tap to expand/collapse)
```
Pending Batches: 3    In Transit: 7    Received: 21    Collected: 25
```

### Sections

| Section | What it shows | Color |
|---|---|---|
| **Pending** | Batches not yet dispatched | Amber |
| **In Transit** | Batches heading to your location | Orange |
| **Received** | Parcels arrived at your location | Green |
| **Collected** | Parcels handed to receivers | Grey |

- **Drawer (☰)** — Settings, Reports, Add User, Updates, Logout
- **+ Add Parcel (FAB)** — Create new parcel (green button)

---

## Creating a Parcel

Tap **+ Add Parcel**. The form opens with today's date and your location pre-filled.

### Form Fields

| Field | Required | Notes |
|---|---|---|
| Document No | Auto | System-generated (e.g., P-00042) |
| Date Sent | Yes | Defaults to today |
| Sender Name | Yes | Person sending |
| Sender ID | No | National ID |
| Sender Phone | Yes | For SMS notifications |
| From | Yes | Auto-filled from your location |
| To | Yes | Destination — tap to search |
| Receiver Name | Yes | Person receiving |
| Receiver ID | No | Receiver's ID |
| Receiver Phone | Yes | For OTP SMS |
| Driver | No | Assigned at dispatch |
| Vehicle | No | Assigned at dispatch |
| Amount (KES) | No | Parcel charges |
| **Payment By** | — | **Sender** or **Receiver** (see below) |
| Parcel Details | No | Item descriptions (add/remove rows) |

### Payment By — Sender vs Receiver

| Option | When payment happens | Workflow |
|---|---|---|
| **Sender** | At drop-off (creation) | Create → Pay → Print → Dispatch → Receive → Collect |
| **Receiver** | At collection | Create → Dispatch → Receive → Pay → Collect |

**Sender-paid:** SMS says "Your parcel DOC001 has arrived. Collection code: 38472. Please come collect it."

**Receiver-paid:** SMS says "Your parcel DOC001 has arrived. Amount due: KES 500. Collection code: 38472. Please pay before collection."

---

## Making Payments

### When to Pay
- **Sender-paid**: Pay immediately after saving the parcel
- **Receiver-paid**: Pay when the receiver arrives to collect

### How to Pay
1. Open the parcel → tap **Pay**
2. Choose: **Cash** or **M-Pesa**
3. Confirm the amount
4. Payment is recorded with your agent code

### After Payment
You're prompted to print a receipt. You can print now or skip.

> **Once a receipt is printed, the parcel is locked from further edits.**

---

## Batches & Dispatching

Parcels from the same origin to the same destination auto-group into batches.

### Dispatch a Batch
1. Expand a **Pending** batch
2. Tap **Dispatch**
3. Select **Vehicle** (required) and enter **Driver** (optional)
4. Tap **Dispatch**

All parcels move from **Pending → In Transit** and sync to Business Central.

---

## In Transit — Tracking Shipments

Shows batches heading to your location. Each card shows:
```
● NAIROBI  |  🚛 KCF 969W
  👤 John (Driver)  📦 5 parcels     [Receive]
```

Expand to see individual parcels. Filtered by your current location.

---

## Receiving & OTP Codes

When a batch arrives:

1. Tap **Receive** on the batch
2. Confirm the dialog
3. All parcels move to **Received**
4. **5-digit OTP codes** generated and sent via SMS to each receiver

### SMS Content
- Paid by sender: "Your parcel DOC001 has arrived at MOMBASA. Collection code: 38472."
- Paid by receiver: "Your parcel DOC001 has arrived. Amount due: KES 500. Collection code: 38472."

---

## Collecting Parcels (OTP Verification)

When a receiver arrives to collect:

1. Find the parcel in **Received**
2. Tap to open the Collect dialog:
```
┌─ Collect Parcel ──────────────────┐
│ DOC001 - John Doe                 │
│ Receiver Phone: ___________       │ ← Required
│ Receiver ID:    ___________       │ ← Optional
│ Collection Code: _____ (5 digits) │ ← Must match SMS code
│                                   │
│ [Use Receiver Details]            │ ← Auto-fills ID & phone
│  [Cancel]              [Collect]  │
└───────────────────────────────────┘
```
3. Ask receiver for their **phone** and **5-digit code**
4. Tap **Use Receiver Details** to auto-fill from parcel data
5. Tap **Collect**

### Code Verification
- Correct code → Parcel collected, synced to BC
- Wrong code → Error: "The collection code entered does not match"
- Old parcels (no OTP) → Collection allowed without code check

---

## Printing Receipts

1. Tap 🖨️ on any saved parcel
2. Select Bluetooth printer (saved for future use)
3. Receipt prints with document number, amounts, date, location

> Printed parcels are **locked** from editing.

---

## Reports & Analytics

**Drawer → Reports**. Default view is **My Collections**.

### Report Types

| Report | Shows |
|---|---|
| **My Collections** | *Default* — Your Cash + M-Pesa totals |
| Status Breakdown | Parcels by status |
| Daily Volume | Parcels per day |
| Revenue | Daily revenue, paid vs unpaid |
| Route Performance | Busiest routes |
| Driver Workload | Parcels per driver |
| Vehicle Workload | Parcels per vehicle |
| Payment Method | Cash vs M-Pesa breakdown |
| Batch Performance | Batch status summary |
| Activity Log | Individual parcel audit trail |

### Export: PDF, CSV, Share, Bluetooth Print

---

## Settings & User Management

### Settings (Drawer → Settings)
- Change Location, Change Password

### Add User (Admin only)
- Agent Code, Name, Phone, Password, Account Type, Location
- Only Admin accounts can create users

---

## Sync, Offline & Auto-Update

- **Offline-first**: All data saved locally, synced when online
- **Auto-sync**: Every 10 seconds
- **Pending parcels**: Never synced until dispatched
- **Auto-update**: Checks for new versions, downloads in background

---

## Troubleshooting

| Problem | Solution |
|---|---|
| Parcels not appearing | Check location matches, pull to refresh |
| Sync issues | Check internet, restart app |
| OTP not received | Verify phone number, check BC |
| Wrong collection code | Ask receiver to re-check SMS |
| App crashes | Restart, check for updates |
| Receipt won't print | Check Bluetooth, printer power/paper |
| Payment not reflecting | Payments sync after dispatch |

---

*Parcel Tracker v1.0.9 — June 2026*
