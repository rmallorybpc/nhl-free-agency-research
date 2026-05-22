# NHL Free Agency Research - Non-Data User Audit Checklist
## A self-run browser audit to find areas of confusion for casual readers

This checklist is designed to be run by a person in a real browser on the live site. It catches what an automated fetch tool cannot: dynamic content rendering, JavaScript behavior, mobile layout, and reader flow.

Site to audit: https://rmallorybpc.github.io/nhl-free-agency-research/welcome.html

## How to use this checklist

- Run through each section in order.
- Note any item that fails or feels confusing.
- Capture the page name and the specific issue.
- Bring the noted issues back as a list and translate them into Copilot fix prompts one by one.

## Pages to audit

1. Welcome - `/welcome.html`
2. Key Findings - `/findings.html`
3. Overview - `/index.html`
4. Team Detail - `/team.html?team=BOS&season=2025`
5. All Signings - `/explorer.html`

For each page, run the test categories below.

## Test 1 - Plain language test

Acronym check: Are there acronyms used without being defined the first time they appear on the page?

Watch for these acronyms specifically - they are common in hockey research but unfamiliar to casual fans:

- UFA - unrestricted free agent
- RFA - restricted free agent
- MIS - Movement Impact Score
- AAV - average annual value
- ELC - entry level contract
- AHL - American Hockey League
- OTL - overtime loss
- LTIR - long term injured reserve
- ECHL - minor league below AHL
- ATO - amateur tryout
- PTO - professional tryout
- ntile, OLS, R-squared, p-value - statistics terms

Jargon check: Are there words that read like a methods textbook?

Flag any sentence containing:

- coefficient, regression, variance, specification
- season-over-season (vs year over year)
- points percentage (vs winning percentage or standings position)
- dependent variable, independent variable, control
- panel, tier, moderator, estimator
- robust across model specifications

For each one you find, note:

- Page name
- The exact phrase used
- A suggested plain-language replacement

## Test 2 - Reading flow test

The 10 second scan test:

- Open the page fresh.
- Scroll once from top to bottom in about 10 seconds.
- Can you state the main point of the page in one sentence?
- If no, the page is buried - the top section needs to lead harder.

The information hierarchy test:

For each card on the page:

- Is the most important number or sentence at the top of the card?
- Or do you have to read through paragraphs to find the point?
- Cards that bury the point need the headline finding moved to the top.

The what-is-this-card-showing-me test:

For each card:

- Read just the title.
- Without reading the body, can you tell what data the card contains?
- If the title is generic (Performance summary) and the data is specific (mean reversion across quartiles), the title needs to change.

## Test 3 - Empty state and edge case test

These catch errors a happy-path test misses.

Overview page:

- Set season selector to the earliest available year (2018).
- Does anything look strange or empty?
- Switch between conferences - does the table update visibly?
- Are teams with $0 MIS shown clearly or hidden?

Team Detail page:

- Pick a team that had zero UFA signings in a season - try LAK 2019 or a similarly quiet team-season.
- Does the page handle it gracefully or show errors?
- Does the MIS breakdown card show a no-signings message or render an empty bar?
- Does the signings table show a helpful empty state?

Team Detail page - URL behavior:

- Load `/team.html` with no query parameters at all.
- Is it obvious what the user should do?
- Do the dropdowns guide them to make a selection?
- Or does it just sit at Loading...?

Team Detail page - pre-2018 attempts:

- Try `/team.html?team=BOS&season=2017`.
- 2017 is outside the analysis window - what does the page do?
- Does it explain that 2016 baseline data is not in scope?
- Or does it show broken or zero values?

All Signings page:

- Apply a filter combination that returns zero results.
- Example: 2024 + Goalie + $10M+ AAV.
- Does the empty state message appear?
- Are active filters clearly visible at the top of the results?
- Click Reset filters - does it actually reset all six filters?

All Signings page - pagination:

- Set filters to All across the board (1648 signings).
- Test the Previous and Next buttons.
- Does the page indicator update correctly?
- Are buttons disabled when at first or last page?

Findings page:

- Open the page.
- Wait 5 seconds without scrolling.
- Do all dynamic sections finish loading?
- Are any places still saying Loading... after the page is fully rendered?

## Test 4 - Navigation test

One-click reach:

- From any page, can you reach any other page in one click?
- Check the top navigation bar on each page.

Active page indicator:

- On each page, is the current page visually distinct in the nav bar?
- It should be highlighted with the sage background.

Cross-page context loss:

- Open Overview, select 2024 season.
- Click a team row to go to Team Detail.
- Does Team Detail open with 2024 selected?
- Or does it default to a different season and lose context?

- From Team Detail, click Back to overview.
- Does Overview remember the season you were looking at?
- Or does it reset to the default?

- From All Signings, click a signing row.
- Does it take you to Team Detail with the correct team and season?

Tool Suite dropdown:

- Open the TMG Tool Suite dropdown on each page.
- Does the NHL Analysis link work? (it used to 404 on some pages)
- Do all other tool links open in a new tab?

## Test 5 - Mobile test

Resize your browser window to 375px wide, or open the site on your phone.

Layout integrity:

- Do all metric tiles stack vertically cleanly?
- Or do they get squeezed or overflow?

Table behavior:

- On Overview, can you read the league ranking table?
- Or does it scroll horizontally awkwardly?
- On Team Detail, can you read the signings table?
- On All Signings, can you read the results table?

Navigation behavior:

- Does the top nav bar still fit at 375px?
- Or do page links wrap awkwardly?
- Is the TMG Tool Suite dropdown still tappable?

Filter usability:

- On All Signings, can you reach all six filters easily?
- Are the dropdowns large enough to tap?
- Is the Reset filters button easy to find?

Reading flow:

- Are paragraph cards readable without horizontal scrolling?
- Do long URLs or numbers break the layout?

## Test 6 - First-time visitor test

Pretend you have never seen this site before. Open Welcome and ask yourself these questions out loud:

The 5 second question:

What is this site? - should be answerable from the hero section alone.

The 30 second question:

What did the research find? - should be clear after scanning the metric tiles and the What this research shows card.

The 2 minute question:

Can I look at a specific team? - should be obvious how to get to Team Detail.

The skeptic question:

How do I know this is trustworthy? - does the site explain data sources and methodology limits up front, or do you have to hunt for them?

## Test 7 - Findings page narrative test

The Key Findings page is the most important page for non-data readers. Run this extra layer of audit on it specifically.

Lead anecdote test:

- After the quartile examples and lead anecdote update is deployed, does the page name a specific team in the lead paragraph of Finding 1?
- Or does it stay abstract?

Verdict clarity test:

- For each of the three findings, can you state the answer in one sentence after reading the first paragraph?
- It should be Yes / No / Sort of in plain words.

Team examples test:

- Does the quartile table show recent recognizable teams?
- Or does it still show direction labels (Negative, Near zero)?

Model comparison test:

- After the plain-language update is deployed, does the model comparison card use Raw dollars and Position-weighted?
- Or does it still say Model A and Model B?

Geography finding test:

- Is the geography section present?
- Does it answer the Freakonomics-inspired question about player movement?

## How to report findings

When you finish the audit, summarize what you found in this format:

```text
Page: [page name]
Test: [which test category]
Issue: [what you observed]
Suggested fix: [your idea or needs Copilot prompt]
```

Bring the list back and each issue gets translated into a precise Copilot prompt - same pattern as the quartile examples and model comparison prompts already on file.

## Priority guidance

If you can only fix a handful of issues, prioritize in this order:

1. Empty states and broken edge cases - they make the site feel broken even when the data is right.
2. Plain language on the Findings page - this is the page people will read most carefully.
3. Mobile layout issues - phones are the most likely first device.
4. Cross-page context preservation - frustrates returning users.
5. Acronym definitions - annoying but readers can usually figure them out.

## When to re-run this audit

Run the full audit again whenever:

- A new finding section is added to the page.
- A new page is added to the site.
- A major data source changes, for example when 2026 season is added.
- Anyone other than you uses the site for the first time and gives feedback - capture friction points and re-test.

Audit version 1.0 - May 2026

This checklist exists because automated fetch tools cannot execute JavaScript and cannot replicate the experience of a real first-time visitor reading the page on their phone.
