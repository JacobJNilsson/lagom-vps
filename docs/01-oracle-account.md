# Stage 1: Oracle account

This stage creates an Oracle Cloud account with a home region. You do it in a browser. No script runs.

Oracle's sign-up is strict and sometimes rejects people with no clear reason. This guide separates three kinds of statements. Oracle's own statements carry a link. Gaps say "Oracle does not say". Community reports are marked as such and are not Oracle policy.

Sources for Oracle's statements, all read on 2026-11-19:

- [Free Tier FAQ](https://www.oracle.com/cloud/free/faq/)
- [Sign Up for a Free Oracle Cloud Promotion](https://docs.oracle.com/en-us/iaas/Content/GSG/Tasks/signingup_topic-Sign_Up_for_Free_Oracle_Cloud_Promotion.htm)
- [Oracle Cloud Free Tier overview](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier.htm)

## Before you sign up

### Pick the home region first

The choice is permanent. The sign-up page says: "You can't change this after signing up." Oracle's [Managing Regions](https://docs.oracle.com/en-us/iaas/Content/Identity/regions/managingregions.htm) page says: "Oracle assigns your home region and you can't change it."

Always Free compute lives only in the home region. Oracle says: "You must create the Always Free compute instances in your home region." Block volumes outside the home region are billed. See [Always Free Resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm).

Choose a region close to you where Ampere A1 is offered. Oracle lists A1 in every availability domain except South Korea North (Chuncheon). The FAQ says: "If your first-choice data region isn't available, please select an adjacent region."

Capacity varies by region and over time. Oracle says "Availability to Free Tier is subject to capacity limits." See [Oracle Cloud Free Tier](https://www.oracle.com/cloud/free/). [Troubleshooting](troubleshooting.md#out-of-host-capacity) covers a full region.

### One account per person

The FAQ says: "One Oracle Cloud Free Trial or Always Free account is permitted per person." It also says: "Creating or attempting to create multiple free accounts is prohibited." The sign-up page adds: "Oracle permits one cloud account to be created per email address."

Do not retry with a second identity after a rejection. Use one email address and one name.

### Account type

Oracle does not say that sign-up offers an Individual or Company account type. The sign-up page only says to optionally enter the name of your company. Use your own name and leave the company field empty if you sign up as a person. If the form shows a type choice, pick the one that matches who owns the card.

### Your card

Oracle's FAQ says: "We accept credit cards and debit cards that function like credit cards." It then says: "We do not accept debit cards with a PIN or virtual, single-use, or prepaid cards."

The sign-up page says that debit cards "that have a major credit card log (for example, Visa, Mastercard, Discover, American Express) and don't require a PIN number can be used."

So these cards fail by Oracle's own rule:

- Prepaid cards.
- Virtual cards and single-use cards, including the disposable numbers that some banks and apps issue.
- Debit cards that need a PIN.

Some debit cards also fail even when they carry a major logo. Oracle does not list which ones. Community reports say that many people succeed with a credit card after a debit card failed. Use a real credit card in your own name when you can.

### Name and address

Oracle does not say how strictly the name and address must match your card. The sign-up steps only say to enter your address and phone number and then your card information. Community reports say that rejections often trace back to a mismatch with the bank's records. Treat that as unconfirmed, and make everything match:

- Enter your name as it appears on the card, with the same spelling.
- Enter the billing address that your card issuer has on file. Check it in your bank's app.
- Use the same street format, unit number and postal code as the bank. If the bank writes "Street" and not "St", write "Street".
- Use the country and region of that address.

### Phone and email

The Free Tier overview says that "most users need a mobile phone number and a credit card to create an account." Use a real mobile number. Oracle does not say whether it sends a code. Community reports say that VoIP numbers may fail, which is unconfirmed.

For email, the sign-up page says: "Select Verify my email. The system sends a verification link to your email address that is valid for 30 minutes." Open the link within 30 minutes, and request a new one if it expires.

### VPNs and a mismatched location

Oracle does not say that a VPN blocks sign-up. Community reports say that a VPN, or a connection from a country other than the card's, can trigger a rejection. Treat that as unconfirmed. Turn the VPN off and sign up from the country of your billing address, on a normal connection. Use a current browser with no ad blocker running on the sign-up page.

## Sign up

1. Open [oracle.com/cloud/free](https://www.oracle.com/cloud/free/) and start the sign-up.
2. Enter your name, email address and country. Verify your email within 30 minutes.
3. Enter your address and mobile phone number.
4. Choose the home region you picked above.
5. Enter your card information.
6. Wait for the confirmation email, then sign in to the console.

## The card hold

The sign-up page says: "You might see a small, temporary charge on your payment method. This is a verification hold that will be removed automatically." The FAQ says: "These holds are removed by your bank, typically within three to five days, and do not result in actual charges to your account."

Oracle does not state the amount. The FAQ says Oracle "may periodically check the validity of your card", which can cause another hold.

The Free Tier overview says: "Your credit card will not be charged unless you upgrade your account." The FAQ says: "Resources identified as Always Free will not be reclaimed." Stay within the limits below and do not upgrade, and the card is not charged for Always Free resources.

## What Always Free gives you

These limits come from [Always Free Resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm), read on 2026-11-19. Oracle modified that page on 2026-06-12.

- Ampere A1 compute: "the first 1,500 OCPU hours and 9,000 GB hours per month for free for VM instances using the VM.Standard.A1.Flex shape". For Always Free tenancies this "is equivalent to 2 OCPUs and 12 GB of memory."
- You can use one instance with 2 OCPU and 12 GB, or up to two instances of 1 OCPU each. The memory is "12 GB total, which you can allocate flexibly".
- Storage is 200 GB in total for boot and block volumes together, in the home region. The default boot volume is 50 GB.

Older guides on the web list larger A1 limits. Oracle has lowered them. An older tenancy may still show a larger quota, so open your tenancy's limits page and read the numbers there.

This repo sizes everything for 2 OCPU and 12 GB. The scripts refuse larger values unless you pass `--allow-paid`.

## If sign-up fails

The most common failure is a message such as "Error processing transaction" after you enter the card. Oracle's pages do not mention this message or its cause. Oracle's advice for sign-up problems is in the FAQ: "Contact the Oracle Cloud support team using the Chat link in the menu bar." For a country that is not on the sign-up list, the FAQ says to contact Oracle Sales or Cloud Support through the same chat.

Community reports, not Oracle policy, describe these steps. They are unconfirmed and no single one works for everyone:

1. Check the name, address and postal code against your bank's records, then try again.
2. Try a different credit card, not a debit, prepaid or virtual card.
3. Turn off the VPN, and try another browser or a private window.
4. Wait a day or two before the next try. Many attempts in a row may make it worse.
5. Ask Oracle's support chat for help. Do not create a second account.

If nothing works, use your own judgment. A free account from another provider is an alternative, but the rest of this repo targets Oracle.

## After sign-up: idle accounts

The FAQ says: "Accounts left idle for 30 days or more may be deemed abandoned and become eligible for suspension or termination." A separate rule can reclaim an idle instance. [Troubleshooting](troubleshooting.md#idle-reclamation) states both.

## Next

Go to [Stage 2: create the instance](02-create-instance.md).

Last checked: 2026-11-19. Oracle's pages were read on that date. The community reports in this guide have no linked threads, so treat them as unverified.
