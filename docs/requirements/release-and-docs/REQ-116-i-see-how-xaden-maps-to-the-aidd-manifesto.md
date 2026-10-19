---
id: REQ-116
type: job
epic: release-and-docs
priority: should
status: done
updated: 2026-10-19
---

# I see how Xaden maps to the AIDD Manifesto, including what it does not meet

## Job

When I judge whether Xaden fits an AI-driven way of working, I want a table from each value and principle of the AIDD Manifesto to the Xaden rule that implements it, with the unmet items listed, so I can check the claim myself.

## Acceptance criteria

- Given the guide `docs/guide/`, then a page holds one row for each of the 4 values and the 12 principles of the manifesto version it names (v1.1.1), with the manifesto's own title, the Xaden rule or requirement ID, a status `met`, `partly` or `not met`, and a link
- Given an unmet or partly met row, then it says so in plain words; where a draft or a requirement for a later release exists, the row names it, and no row lists a requirement that does not exist
- Given the rows for principle 07 (own every shipped change) and principle 11 (treat AI failure as a signal), then they cite the rules that implement them today (REQ-110, REQ-111)
- Given the page, then it says that Xaden "implements" the manifesto; it never says "certified", "endorsed" or "official", claims no affiliation and shows no badge or logo
- Given the manifesto's license (CC BY 4.0), then the page names title, source link, version and license link, and says the table is Xaden's own work; `THIRD-PARTY.md` lists the manifesto and `scripts/check-third-party.sh` passes (REQ-113)
- Given a commit, then `Signed-off-by` is described as optional and Xaden neither requires nor generates it
- Given the page links to a Xaden rule or requirement, then a check fails when that target does not exist
- Given `docs/site-pages.txt`, then it lists the page, so the next release carries it to the website
