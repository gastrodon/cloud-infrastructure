# The Glade — pack update plan (2026-08)

Resolved against the live manifest at `minecraft/pack/glade-mods.json`
(141 mods, Minecraft 1.20.1 / Forge 47.4.10) on **2026-08-17**.

**Headline:** 19 mods updated, 2 removed (+1 proposed), 17 added (+2 transitive
deps), Icarus deliberately held at 2.13.2. Net pack goes 141 → 157 mods.

**Decided 2026-08-17:** *Better End* **dropped** — no Forge 1.20.1 build, broken
under Sinytra Connector (§3.1). *Nirvana* is the **CurseForge hemp/herb mod**
(§3.2). *Obscure API* **dropped** as orphaned (§3.3). The **End will be reset**
so YUNG's Better End Island actually applies (§3.6, procedure in §7.6a).

> **⏸ Status: built, not deployed.** Manifest + config implemented, client pack
> / server tree / AMI all built locally and verified. `tofu apply` deliberately
> **not** run — held pending client-pack testing. See **§10** for the build
> record, the full 306-edge dependency audit, and what was deliberately skipped.

---

## 1. Orientation — how this pack is actually built

Worth reading before touching anything; the whole change is one JSON file plus a
config tree, and everything else is derived.

| Thing | Where | Notes |
|---|---|---|
| Authoritative mod list | `minecraft/pack/glade-mods.json` | Each entry: resolved `url`, `source`, `sha1`/`sha512`, `side` |
| Builder | `minecraft/pack/glade-mods.nix` | `.server` = mods with `side != "client"`; `.prism` = Prism instance zip of **all** mods |
| Server config tree | `minecraft/pack/config/**` | Vendored in-repo, copied into the store, two lines patched in `glade.nix` |
| Forge server | `minecraft/pack/forge-server.nix` | FOD that runs the Forge installer; unchanged here |
| Server definition | `minecraft/glade.nix` | Symlinks each jar into `mods/`, installs `config` via `files."config"` |
| AWS platform | `minecraft/aws.nix` (prod) / `aws-staging.nix` (staging) | EFS world, EIP claim, spot watcher |
| Build + deploy | `aws/minecraft/{ami.tf,modpack.tf,build-ami.sh,build-client.sh}` | `local.ami_src_hash` fingerprints `minecraft/**` + `flake.*` |

Two consequences that matter for this change:

1. **`side` only gates the *server* set.** `clientMods = manifest.mods` — the
   Prism zip contains *every* entry regardless of `side`. So `side: "server"` vs
   `side: "both"` is documentation only; only `side: "client"` changes a build
   (it excludes the jar from the server). Don't agonise over it.
2. **Any edit under `minecraft/**` re-triggers both builds.** `ami_src_hash` in
   `ami.tf` hashes every file under `minecraft/`, and `modpack.tf`'s
   `null_resource.client_build` reuses that same trigger. One `tofu apply`
   rebuilds the AMI *and* republishes `The_Glade.zip`, in lockstep. There is no
   separate "just ship the client" path, and that's intentional.

---

## 2. Where each mod came from (research method)

No Playwright was used, and none is needed:

- **Modrinth** — `https://api.modrinth.com/v2`. The pinned version id is
  embedded in every CDN url (`/data/{project}/versions/{version}/{file}`), so
  the current pin is recoverable via `GET /v2/version/{id}`. Latest candidates
  come from `GET /v2/project/{id}/version?game_versions=["1.20.1"]`, filtered to
  the **same loader set as the current pin** (this is what stops a Fabric-only
  build being picked for a Forge entry) and sorted by `date_published`.
  `files[].hashes` gives both sha1 and sha512 directly — no download needed.
- **CurseForge** — the official `api.curseforge.com` needs an API key we don't
  have (403), and `www.curseforge.com/api/v1/mods/search` + the HTML pages are
  Cloudflare-blocked. But **`https://www.curseforge.com/api/v1/mods/{id}/files`
  is open** and returns the full file list with `gameVersions`, so once you have
  a numeric project id everything else follows. Download url is the documented
  forgecdn path: `files/{fileId / 1000}/{fileId % 1000}/{filename}` (no
  zero-padding on the second segment — `7766058` → `7766/58`). CurseForge
  serves no hashes, so **sha1 is computed locally from the downloaded jar**,
  which is what the existing CurseForge entries already do.
- **slug → project id** for CurseForge, when search is blocked:
  `https://api.cfwidget.com/minecraft/mc-mods/{slug}` and
  `https://api.cfwidget.com/author/search/{author}` (the latter is what found
  *Devourer of Gods*; cfwidget's slug cache for `dog` is stale and resolves to
  the wrong project, the author lookup does not).
- **Finding the two unlisted-on-Modrinth mods** — `search.brave.com` over plain
  `curl` still returns parseable HTML (DuckDuckGo and Mojeek both 403/CAPTCHA).
- **Dependency verification** — every candidate jar was downloaded and its
  `META-INF/mods.toml` read with `jar xf` (§5). This is stronger than trusting
  Modrinth's declared dependency list, which is frequently wrong in both
  directions (Mystic Seas declares three *required* deps that the jar marks
  `mandatory=false`).

Re-runnable resolver scripts are in `/tmp/glade-research/` (`resolve-existing.mjs`,
`resolve-cf.mjs`, `resolve-new.mjs`, `cf-files.mjs`, `inspect-deps.sh`). Consider
vendoring a cleaned-up version as `minecraft/pack/resolve.mjs` so the next bump
is a one-command diff — optional, and out of scope for this change.

---

## 3. Decisions

> **Settled 2026-08-17:** §3.1 Better End **dropped**; §3.2 Nirvana is the
> **CurseForge hemp/herb mod**; §3.3 Obscure API **dropped** (orphan status
> since verified against the rebuilt tree — §10); §3.6 the End **will be reset**.
> §3.4–§3.5 are accepted-risk notes, not choices. Remaining open items are in §9.

### 3.1 ✅ DECIDED — "Better End" is dropped

**Decision: not shipped.** No substitute sought; *YUNG's Better End Island* and
*End Remastered* (both on the add list) cover the End work.

Why it was never viable: `BetterEnd` (Team BetterX / paulevs, Modrinth
`betterend`, CurseForge 413596) has **no Forge build for 1.20.1 and never will**:

- Latest 1.20.1 file is `better-end-4.0.11.jar` (2023-12-20, **beta**), tagged
  `Fabric` only. The NeoForge revival (`BetterEnd: New Dawn`) starts at 1.21.
- It hard-requires `bclib`, which requires `wunderlib` — both Fabric-only, both
  deep worldgen/mixin libraries.
- Running it through Sinytra Connector (which this pack does ship) is
  **documented-broken**: Sinytra/Connector [#283 "Incompatiblity with
  BetterEnd"](https://github.com/Sinytra/Connector/issues/283), plus a long tail
  of BCLib+Connector crash reports. Connector explicitly does not support mods
  that bring their own worldgen registry layer.

Nothing in the manifest, the config tree or Appendix A references it — there is
no work item attached to this decision. If a Forge-1.20.1-native End overhaul is
wanted later, that's a separate change.

### 3.2 ✅ DECIDED — "Nirvana" is the CurseForge hemp/herb mod

**Decision: CurseForge project `1278909`, `nirvana-forge-1.2.5.jar`** (release,
2026-03-16, 623k downloads). Already encoded in Appendix A.2 — no edit needed.

| Candidate | Where | What it is | Requires |
|---|---|---|---|
| **Nirvana** ✅ **chosen** | CurseForge **1278909**, `nirvana-forge-1.2.5.jar` | Hemp/herb content mod | **Kotlin for Forge ≥4.0** (already in pack), Create optional ✓ |
| ~~Nirvana Library~~ | Modrinth `nirvana-library` | Library for Clefal's mods | Common Network + Fzzy Config (**not** in pack) |

Nirvana **Library** is not being added. It exists only to support Clefal's *Iron
Furnace: Reburn* / *Loot Beams: Refork*, neither of which is in this pack, and
would have dragged in **Fzzy Config** as a further new dependency. That
dependency is therefore **not** needed — ignore any reference to it.

### 3.3 🟡 Aquamirae 6.4.0 → 7.1.11 is a major rewrite, and it is not optional

"Update everything" forces this, and *Fragmentum* on the add list confirms it's
intended — Fragmentum **is** the reason Aquamirae 7 exists:

```
aquamirae-forge-1.20.1-7.1.11.jar → mods.toml
    fragmentum  mandatory=true  [1.5.2,)
    geckolib    mandatory=true  [4.8.0,)     ← pack has 4.8.4 ✓
```

Consequences to accept up front:

- **Obscure API is orphaned by this.** A scan of every jar in the current build
  found exactly two references to `obscure_api`: Aquamirae 6.4.0 and
  `obscure_api-18.jar` itself. Aquamirae 7 dropped it for Fragmentum.
  → **Proposed extra removal** (§4.3). Re-run the scan after the rebuild to be
  sure (§7.4); leaving it in is harmless-but-dead if you'd rather not.
- **Config moves.** `config/Obscuria/aquamirae-{client,common}.toml` and
  `config/Obscuria/obscure-api-client.toml` will be stale. Aquamirae 7 writes
  its own tree on first boot; capture it on staging and vendor it (§7.3).
- **World risk.** The Ship Graveyard biome and its structures were reworked
  between 6 and 7. Existing Aquamirae structures/entities in already-generated
  chunks may break or de-register. This is the single highest-risk item in the
  change — it is the reason for the staging pass in §7.5.
- 7.1.11 is Modrinth **beta** channel; 6.4.0 was release. The whole 7.x line for
  1.20.1 is beta — there is no 7.x release build to pick instead.

### 3.4 🟡 Removing AstikorCarts Redux destroys player property

`astikorcarts` entities in the live world will vanish on next load. Nothing else
in the pack depends on it (verified by jar scan), so it's clean *technically* —
but announce it, and consider a `/give`-back for anyone who had carts.

### 3.5 🟡 JEI jumps 29 minor versions (15.20 → 15.49)

JEI's 1.20.1 line is published on the **beta** channel by convention (the
current pin, 15.20.0.134, is beta too — this is not a channel downgrade).
`mods.toml` shows no new dependency. The pack's JEI-adjacent mods are fine:
Sophisticated Core/Backpacks want `jei ≥15.20.0.106` (client, optional), and
`Searchables`/`Controlling` are unchanged. Low risk, but it's the biggest single
version jump in the update set, so eyeball the JEI screen on staging.

---

### 3.6 ✅ DECIDED — the End dimension **will be reset**

**Decision: delete `world/DIM1` so the End regenerates**, giving YUNG's Better
End Island a fresh main island to build (otherwise it is inert on an
already-generated End — the mod only shapes chunks at generation time).

This is a **destructive world edit**, not a pack change, and it is the single
most dangerous step in the whole deploy. It is deliberately **not** bundled into
`tofu apply` — it is a separate, manual, server-stopped operation: see **§7.6a**.

Blast radius — what is destroyed:

- **Every player build, chest and item left in the End.** End cities revert to
  unlooted, elytra/shulkers taken from them stay taken (they're in player
  inventories), but anything *stored* in the End is gone.
- All End gateways, the obsidian return platform, and the dragon-fight state —
  **the ender dragon respawns** and must be re-killed.

What is *not* touched: player inventories, ender-chest contents (per-player in
`playerdata`), the Overworld, the Nether, and the lit stronghold End portal.

Note this does **not** make End Remastered's 12-eye portal quest apply: that
gates *lighting* the stronghold portal, which is in the Overworld and already
lit. Resetting that too would mean editing the stronghold — out of scope, ask if
wanted.

## 4. Change set

### 4.1 Updates — 19 mods

18 from Modrinth + 1 from CurseForge. Every one is 1.20.1 + the same loader as
the current pin. Full manifest entries with urls and hashes: **Appendix A.1**.

| mod | from → to | published | channel |
|---|---|---|---|
| Aquamirae | `6.4.0` → `7.1.11` | 2026-08-17 | beta ⚠ |
| Companions! | `1.2.3` → `1.3.2` | 2026-08-08 | release |
| Data Anchor | `1.0.0.20-forge` → `1.0.0.22-forge` | 2026-08-06 | release |
| Forgified Fabric API | `0.92.6+1.11.14+1.20.1` → `0.92.6+1.11.15+1.20.1` | 2026-08-13 | release |
| Golem Overhaul | `1.1.0` → `1.1.1` | 2026-07-27 | release |
| Hybrid Aquatic | `1.6.7-forge` → `1.6.9-forge` | 2026-08-07 | release |
| Just Enough Items (JEI) | `15.20.0.134` → `15.49.0.188` | 2026-08-11 | beta ⚠ |
| Lost Trinkets Renewed | `20.1.3-mc1.20.1-forge` → `20.1.4-mc1.20.1-forge` | 2026-07-14 | release |
| More Critters | `1.4.3` → `1.4.5` | 2026-08-08 | release |
| OneKeyMiner | `1.20.1-1.6.6-universal` → `1.20.1-1.6.9-forge` | 2026-08-09 | release |
| Roundabout: The JoJo Mod | `3.1.7` → `3.4.4` | 2026-08-16 | release |
| Saint's Dragons | `0.8.2` → `0.9.3` | 2026-08-10 | release |
| Simple Voice Chat | `forge-1.20.1-2.6.21` → `forge-1.20.1-2.6.22` | 2026-08-08 | release |
| Sophisticated Backpacks | `1.20.1-3.24.59.1960` → `1.20.1-3.24.66.2095` | 2026-08-15 | release |
| Sophisticated Backpacks Create Integration | `1.20.1-0.1.8.116` → `1.20.1-0.1.9.151` | 2026-08-15 | release |
| Sophisticated Core | `1.20.1-1.3.66.2138` → `1.20.1-1.3.80.2267` | 2026-08-15 | release |
| Via Romana | `2.2.2+1.20.1-forge` → `2.2.3+1.20.1-forge` | 2026-08-13 | release |
| Whaleborne | `1.20.1-1.2.3` → `1.20.1-1.2.4b` | 2026-08-12 | release |
| Skarrier Mobs *(CurseForge)* | `1.0.5(beta)` → `1.0.6` | 2026-08-13 | beta |

Notes:

- **The Sophisticated trio must move together.** `sophisticatedbackpacks-3.24.66`
  requires `sophisticatedcore ≥1.3.80.+`; `…createintegration-0.1.9.151` requires
  `sophisticatedbackpacks ≥3.24.66` **and** `create ≥6.0.7` (pack has 6.0.8 ✓).
  Bumping one without the others is a hard load failure.
- **OneKeyMiner changes filename shape** — the old jar was the `-universal`
  build, the new one is `onekeyminer-forge-1.6.9-1.20.1.jar`. Same project.
- The other 110 Modrinth mods are already on the newest 1.20.1 build for their
  loader; the other 11 CurseForge mods are likewise current. No action.

### 4.2 Pinned — Icarus stays at 2.13.2

`Icarus-Forge-2.13.2.jar` (Modrinth `Dw7M6XKW`, version `ozZnrBG3`). **2.14.0 is
available** (2026-06-14, release) and is deliberately *not* taken. Leave the
manifest entry byte-for-byte untouched. Worth adding a one-line comment in the
manifest note so the next bump doesn't "helpfully" fix it.

### 4.3 Removals

| mod | manifest `filename` | notes |
|---|---|---|
| **Mobs Blocker** | `mobs_blocker-1.2.0-forge-1.20.1.jar` | `side: server`. Functionally superseded by *Easy Mob Spawn Control* on the add list. No dependents. |
| **AstikorCarts Redux** | `astikorcarts-1.20.1-1.1.8.jar` | No dependents. **Deletes existing cart entities** — see §3.4. Also delete `minecraft/pack/config/astikorcarts-common.toml`. |
| **Obscure API** ✅ *(decided — dropped)* | `obscure_api-18.jar` | Orphaned by Aquamirae → 7.x. **Orphan status verified against the rebuilt 148-jar tree** (§10): zero remaining `obscure_api` references. Whole `config/Obscuria/` tree removed with it. |

Note the update pass would otherwise bump AstikorCarts to 1.2.5 — skip it, it's
being deleted.

### 4.4 Additions — 17 requested + 2 transitive deps

Full manifest entries: **Appendix A.2** and **A.3**.

| mod | source | version | side | required deps (all satisfied) |
|---|---|---|---|---|
| Call From The Depths | Modrinth `oeL19pc1` | `3.7.7` | both | — (optional: worldedit ✓, geckolib ✓, huge_structure_blocks ✗) |
| Cozy's Improved Cats | Modrinth `5MaZBjPT` | `1.3.0-Forge-1.20.1` | both | — (optional: Cozy's Improved Wolves, not added) |
| Creator Comes Early | CurseForge `1064936` | `1.0.1` | both | — |
| Devourer of Gods | CurseForge `1630975` | `1.1.0` | both | geckolib `[4.8,5.0)` ✓ 4.8.4; cloth_config `[11.0,12.0)` client-optional ✓ 11.1.136 |
| Easy Mob Spawn Control | Modrinth `pTXV6gwq` | `1.5.6` | server | — |
| End Remastered | Modrinth `ZJTGwAND` | `5.3.3-R-1.20.1` | both | — |
| Fish 'N' Ships | Modrinth `dBB5hLnG` | `mc1.20.1-1.0.0-forge` | both | forge `[47.4.10,)` ✓ **exactly**; Kotlin for Forge ✓; geckolib ✓ |
| Fragmentum | Modrinth `49C5QgTK` | `1.5.2` | both | forge `[47.2.0,)` ✓ — **required by Aquamirae 7** |
| Hexal | Modrinth `aBVJ6Q36` | `0.3.1` | both | hexcasting `≥0.11.1-6` ✓ 0.11.3; paucal `[0.6.0,0.7.0)` ✓; patchouli `≥1.20.1-80` ✓ 85; **moreiotas `≥0.1.1`**; geckolib ✓ |
| Hybrid Blocks | Modrinth `61Q9LmD0` | `1.3.0-forge` | both | forge `[47.4.10,)` ✓; Kotlin for Forge ✓ |
| Hybrid Delights | Modrinth `WR49BBCu` | `1.2.1-forge` | both | hybrid_aquatic ✓ (→1.6.9); farmersdelight ✓ 1.3.2; Kotlin for Forge ✓ |
| MoreIotas | Modrinth `Jmt7p37B` | `0.1.2` | both | hexcasting ✓, paucal ✓, patchouli ✓, Kotlin for Forge ✓ |
| Mystic Seas | Modrinth `fmYbzjGG` | `1.1.0` | both | all soft: curios ✓, geckolib ✓, **kleidersplayerrenderer → add** |
| Nirvana *(hemp/herb — §3.2)* | CurseForge `1278909` | `1.2.5` | both | **kotlinforforge `[4.0,)`** ✓ 4.12.0; create optional ✓ |
| Ocean's Enhancements | Modrinth `guq90zGR` | `1.0.0` | both | geckolib optional ✓ — ⚠ **alpha**, only build, 2024-07-01 |
| Sketchy Books | Modrinth `Cuw1AXG3` | `1.1.0` | both | — |
| YUNG's Better End Island | Modrinth `2BwBOmBQ` | `1.20-Forge-2.0.6` | server | **yungsapi `≥1.20-Forge-4.0.1` → add** |
| ↳ YUNG's API | Modrinth `Ua7DFN59` | `1.20-Forge-4.0.6` | both | new transitive dep |
| ↳ Kleiders Custom Renderer API | Modrinth `oaG6aa1j` | `7.4.1` | both | new transitive dep — Modrinth calls it required, the jar marks it optional; **add it anyway** or mermaid tails won't render |

**Kotlin for Forge was requested but is already in the pack** at `4.12.0`, which
is the newest 1.20.1 build. No change — it's on the list because Fish 'N' Ships,
Hybrid Blocks, Hybrid Delights and Nirvana all hard-require it.

### 4.5 Size impact

| | before | after (est.) |
|---|---|---|
| server mod tree | 435 MiB | ~555 MiB |
| client mod tree | 469 MiB | ~590 MiB |
| `The_Glade.zip` (published) | **424 MiB** | **~545 MiB** |

Roughly **+120 MiB**, dominated by Call From The Depths (26 MiB), Aquamirae 7
(26 MiB), MoreIotas (21 MiB), Devourer of Gods (20 MiB), Creator Comes Early
(12 MiB), Ocean's Enhancements (10 MiB).

Check before shipping: the AMI image build pins an 8 GiB root
(`image.modules.amazon.virtualisation.diskSize` in `aws.nix`/`aws-staging.nix`)
and the current `.vhd` is 3.6 GiB, so ~120 MiB of extra closure is comfortable —
but if the image build ever fails on space, that's the knob. The 16 GiB runtime
volume in `main.tf`'s launch template is unaffected.

---

## 5. Compatibility verification already done

Every candidate jar was downloaded and its `META-INF/mods.toml` read. Findings
that changed the plan:

- ✅ Hexal's dependency chain is fully satisfiable **only because MoreIotas is
  also on the list** — Hexal `0.3.1` hard-requires `moreiotas ≥0.1.1`. Good pick.
- ✅ Hexal/MoreIotas want `paucal [0.6.0,0.7.0)` — pack has exactly `0.6.0`. A
  future PAUCAL bump to 0.7.x would break both; PAUCAL has no newer 1.20.1 build
  so this is stable today.
- ✅ Fish 'N' Ships and Hybrid Blocks require `forge [47.4.10,)`. The pack is on
  **exactly** 47.4.10 (`forge-server.nix`). Satisfied, with zero headroom —
  don't downgrade Forge.
- ✅ Aquamirae 7 needs `geckolib ≥4.8.0`; pack has 4.8.4.
- ✅ Devourer of Gods needs `geckolib [4.8,5.0)`; pack has 4.8.4. **Geckolib is
  now pinned from both sides** by Aquamirae and DoG — note it for future bumps.
- ✅ Metus Oblita and Skarrier Mobs are MCreator mods with only an *optional*
  geckolib dep — they are **not** Obscuria mods and do not need Obscure API.
  This is what makes the Obscure API removal in §4.3 safe.
- ⚠️ Hybrid Delights declares `hybrid_aquatic = "1.6.3"` and
  `farmersdelight = "1.20.1-1.3.2"` as bare versions. In Forge/Maven range
  syntax a bracket-less version is a *soft* requirement that always passes, so
  1.6.9 is fine — but if Forge ever logs a mismatch here, that's why.
- ⚠️ Mystic Seas' jar marks **all** its deps `mandatory=false`, including
  `kleidersplayerrenderer`. It will load without it and silently lose the tail
  renderer. Adding Kleiders is a deliberate choice, not a hard requirement.

---

## 6. Risk register

| # | risk | likelihood | impact | mitigation |
|---|---|---|---|---|
| R1 | Aquamirae 6→7 corrupts/orphans existing Ship Graveyard content | med | high | Staging boot on a **copy** of the live world (§7.5); EFS snapshot first (§7.1) |
| R2 | Removing AstikorCarts deletes player carts | **certain** | med | Announce; optional compensation |
| R3 | A new worldgen mod (End Remastered, Call From The Depths, YUNG's BEI) only affects ungenerated chunks | high | low | Expected — see §8 |
| R4 | **End reset destroys all player-built content in the End** | **certain** | **high** | Decided: the End *is* being reset (§3.6) so YUNG's Better End Island actually applies. Procedure + blast radius in §7.6a. Announce loudly; take the `DIM1` backup |
| R5 | End Remastered's 12-eye portal is moot if the End portal is already lit | high | low | Cosmetic/structural content still lands. Accept |
| R6 | Ocean's Enhancements is a 2-year-old alpha with one build | med | med | Ship last / behind a flag; drop it if staging logs errors. Content overlaps Hybrid Aquatic |
| R7 | JEI 29-minor jump misbehaves | low | med | Staging client check (§7.5) |
| R8 | Client pack grows ~120 MiB → slower player download | certain | low | Accept; it's a one-off Prism import |
| R9 | `tofu apply` rolls the AMI and the ASG replaces the box → downtime | certain | med | Rolling refresh with `min_healthy_percentage = 0` means the old instance dies first. Schedule off-peak; expect ~5–10 min |
| R10 | New mods' generated configs are wiped every restart | certain | low | `files."config"` recopies from the store each start — vendor the generated configs (§7.3) or accept defaults |
| R11 | Forge 47.4.10 is the floor for two new mods | low | high | Never downgrade `forgeVersion` in `forge-server.nix` |

---

## 7. Execution plan

### 7.0 — Branch

```bash
cd ~/code/cloud-infrastructure
git checkout -b glade-pack-2026-08
```

### 7.1 — Back up the live world *first*

Non-negotiable before an Aquamirae-major-bump deploy. The world is on EFS
(`aws_efs_file_system.mc`, id from `tofu output efs_id`), which has **no backup
configured in this repo**.

```bash
cd aws/minecraft && tofu output efs_id
# then, one of:
aws backup start-backup-job --backup-vault-name Default \
  --resource-arn arn:aws:elasticfilesystem:us-east-1:050883687565:file-system/<efs-id> \
  --iam-role-arn arn:aws:iam::050883687565:role/service-role/AWSBackupDefaultServiceRole
# or, simplest: ssh to the live box and tar the world off to S3
ssh <server_address> 'sudo tar -C /srv/minecraft -czf - glade/world' \
  | aws s3 cp - s3://gastrodon-glade-ami/backups/glade-world-$(date +%Y%m%d).tgz
```

Record the AMI currently in service for rollback:

```bash
tofu output ami_id                                   # current AMI
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names minecraft
```

### 7.2 — Edit the manifest

Single file: `minecraft/pack/glade-mods.json`.

1. **Replace** the 19 objects in §4.1 with Appendix A.1. Join on `name`; carry
   `side` over unchanged (A.1 already does).
2. **Delete** the `Mobs Blocker` and `AstikorCarts Redux` objects. Delete
   `Obscure API` too if taking §3.3's recommendation.
3. **Do not touch** the `Icarus` object.
4. **Append** the 17 objects from Appendix A.2 and the 2 from A.3.
5. Extend the manifest `note` field: record that Icarus is intentionally pinned
   at 2.13.2, and that CurseForge sha1s are computed locally.

Sanity check the result:

```bash
cd minecraft/pack
# 141 - 2 removals - 1 (Obscure API, if taken) + 17 adds + 2 deps = 157  (158 if Obscure API stays)
jq -e '.mods | length == 157' glade-mods.json
jq -r '.mods[].filename' glade-mods.json | sort | uniq -d          # expect empty
jq -r '.mods[] | select(.sha1 == null and .sha512 == null) | .name' glade-mods.json   # expect empty
jq -r '.mods[] | select(.source=="curseforge" and .sha1==null) | .name' glade-mods.json  # expect empty
jq -r '.mods[] | select(.name=="Icarus") | .filename' glade-mods.json   # Icarus-Forge-2.13.2.jar
```

### 7.3 — Config tree

Delete configs for removed mods:

```bash
cd minecraft/pack/config
git rm astikorcarts-common.toml
# if Obscure API is dropped:
git rm Obscuria/obscure-api-client.toml Obscuria/Data/obscure_api_cover.png
# Aquamirae 7 relocates its config; stale 6.x files:
git rm Obscuria/aquamirae-client.toml Obscuria/aquamirae-common.toml Obscuria/Data/aquamirae_cover.png
```

(There is no `mobs_blocker` config file — nothing to remove.)

New mods will write default configs on first boot. Because `glade.nix` installs
`config` via `files."config"`, that tree is **recopied from the store on every
start** — so anything generated at runtime is lost on restart. After the staging
boot in §7.5, pull the generated files back and vendor them:

```bash
scp -r <staging-ip>:/srv/minecraft/glade/config /tmp/glade-config-new
# diff, then copy in only the genuinely new files (do not clobber curated ones)
```

Then commit them. Also re-check `glade.nix`'s two `--replace-fail`
`substituteInPlace` calls still match (`private_area-common.toml`,
`sculkhorde_config.toml`) — neither mod is changing, so they should, and the
build hard-fails if not.

### 7.4 — Build and verify locally (no AWS)

```bash
cd ~/code/cloud-infrastructure

# 1. the client pack — the exact artefact S3 will serve. Fetches and
#    hash-verifies every jar in the manifest, so a bad url/hash fails here,
#    cheaply, before any AWS work.
nix build --out-link result-glade-client .#gladeClient
ls -la result-glade-client/

# 2. the server mod tree (only `.prism` is a flake output; `.server` is reached
#    through the derivation directly — this is what the stale `result-glade-server`
#    symlink in the repo root came from)
nix build --impure --out-link result-glade-server \
  --expr 'with import <nixpkgs> {}; (callPackage ./minecraft/pack/glade-mods.nix { }).server'

# 3. the full system closure (catches config-tree build failures, e.g. a
#    substituteInPlace --replace-fail that no longer matches)
nix build --no-link .#nixosConfigurations.glade-aws.config.system.build.toplevel
```

> Small quality-of-life fix worth folding in: `flake.nix` exposes `gladeClient`
> but not the server mod tree, which is why step 2 needs `--impure --expr`.
> Adding `packages.x86_64-linux.gladeServer = (... callPackage
> ./minecraft/pack/glade-mods.nix { }).server;` next to `gladeClient` would make
> this a plain `nix build .#gladeServer`.

Post-build assertions:

```bash
# jar count matches the manifest's server set
ls result-glade-server/mods/*.jar | wc -l
jq '[.mods[] | select(.side != "client")] | length' minecraft/pack/glade-mods.json

# removed mods really are gone
ls result-glade-server/mods/ | grep -Ei 'astikor|mobs_blocker|obscure_api'   # expect empty

# Icarus is still 2.13.2
ls result-glade-server/mods/ | grep -i icarus

# nothing still references obscure_api (confirms §3.3)
for j in result-glade-server/mods/*.jar; do
  rm -rf /tmp/_t && mkdir /tmp/_t && (cd /tmp/_t && jar xf "$j" META-INF/mods.toml 2>/dev/null)
  grep -qi obscure_api /tmp/_t/META-INF/mods.toml 2>/dev/null && echo "still needs obscure_api: $j"
done
```

The Mutant More mixin patch in `glade-mods.nix` is keyed on modrinth id
`GmuH0lCA` and guarded by `jq -e`. Mutant More is **not** changing, so it will
keep applying — if the build fails with *"MapDecorationTypeMixin no longer in
client list"*, something bumped Mutant More by accident.

### 7.5 — Staging boot (strongly recommended given §3.3)

`glade-staging` is the same server on a single on-demand instance with a
**local-disk world, no EFS, no EIP claim** — it cannot touch production.

```bash
nix build --out-link result-staging .#stagingImage
```

Then register + launch it out-of-band (same image → snapshot → AMI dance as
`ami.tf`, done by hand — `build-ami.sh` shows the exact metadata shape). Launch
with a ≥16 GiB root volume and the `minecraft` security group.

On the box:

```bash
journalctl -u minecraft-server-glade -f
# look for: mod-loading errors, missing-dependency screens, registry mismatches,
# Aquamirae/Fragmentum init, Hexal+MoreIotas registration, Connector warnings
systemctl is-active minecraft-server-glade
ss -Htln 'sport = :25565'      # must bind, or the liveness watcher will loop
```

Then, for **R1**, copy a snapshot of the live world onto staging and boot it —
that is the only way to see whether Aquamirae 7 survives existing Aquamirae
chunks:

```bash
aws s3 cp s3://gastrodon-glade-ami/backups/glade-world-<date>.tgz - \
  | ssh <staging-ip> 'sudo tar -C /srv/minecraft -xzf - && sudo systemctl restart minecraft-server-glade'
```

Finally, import `result-glade-client/The_Glade.zip` into Prism and join staging.
Check: JEI opens and indexes, Hexal/MoreIotas patterns appear in the Hex book,
Aquamirae content renders, mermaid tails render (Kleiders), no missing-texture
spam.

**Terminate the staging instance when done** — it is on-demand, not spot.

### 7.6 — Ship to production

Everything is driven by the source hash; there is no manual upload step.

```bash
cd aws/minecraft
tofu plan     # expect: null_resource.ami_build + client_build replaced (trigger
              # moved), then s3 object, snapshot import, aws_ami, launch template
tofu apply
```

What that does, in order:

1. `build-ami.sh` → `nix build .#amazonImage` → `ami-image.json` + `result-ami`
2. `build-client.sh` → `nix build .#gladeClient` → `client-pack.json` + `result-client`
3. uploads the `.vhd` to `s3://gastrodon-glade-ami/ami/<hash>.vhd`
4. `aws_ebs_snapshot_import` (up to 60 min — this is the slow step)
5. registers `aws_ami.mc` as `minecraft-nixos-<hash>`
6. new launch template version → ASG **rolling instance refresh** with
   `min_healthy_percentage = 0`, so the old box terminates first
7. uploads `The_Glade.zip` to the public modpack bucket

Because everything is keyed on the image's output-path hash, re-applying with no
change is a no-op. To force a rebuild:
`tofu apply -replace=null_resource.ami_build`.

Watch the swap:

```bash
aws autoscaling describe-instance-refreshes --auto-scaling-group-name minecraft
tofu output server_address client_pack_url
```

### 7.6a — Reset the End (§3.6) — **manual, server stopped, do this ONCE**

Destructive and irreversible without the backup. Deliberately **not** part of
`tofu apply`: the AMI is stateless and the world is on EFS, so this is a
separate operation on the running instance *after* the new AMI is in service.

**Announce first.** Everything players built in the End is about to be deleted
(§3.6), and the dragon comes back.

```bash
ADDR=$(cd aws/minecraft && tofu output -raw server_address)

# 0. everyone out of the End, then stop the server cleanly (this saves + unloads)
ssh $ADDR 'sudo systemctl stop minecraft-server-glade'
ssh $ADDR 'systemctl is-active minecraft-server-glade'      # expect: inactive

# 1. discover the actual layout — do NOT assume, some mods add sibling dims
ssh $ADDR 'sudo ls -la /srv/minecraft/glade/world/'
ssh $ADDR 'sudo ls -la /srv/minecraft/glade/world/DIM1/ /srv/minecraft/glade/world/dimensions/ 2>/dev/null'

# 2. back up JUST the End, separately from the §7.1 full backup, so it can be
#    put back without rolling the whole world
ssh $ADDR 'sudo tar -C /srv/minecraft/glade/world -czf - DIM1' \
  | aws s3 cp - s3://gastrodon-glade-ami/backups/glade-DIM1-$(date +%Y%m%d).tgz

# 3. delete the End
ssh $ADDR 'sudo rm -rf /srv/minecraft/glade/world/DIM1'

# 4. start; the End regenerates on first entry, with YUNG's island shape
ssh $ADDR 'sudo systemctl start minecraft-server-glade'
```

Notes:

- **`DIM1` is the vanilla End.** Modded dimensions live under
  `world/dimensions/<namespace>/<path>` — leave those alone. Call From The
  Depths adds one; deleting it is *not* wanted.
- Step 2 is not optional. It is the only route back if the regenerated End is
  wrong (e.g. YUNG's island didn't apply after all, per the staging rehearsal).
- The dragon fight state lives inside `DIM1`, which is why the dragon respawns.
  That's intended — it's the point of regenerating the island.
- Verify after: fly to the End, confirm the main island has YUNG's structure
  rather than vanilla, and that `world/DIM1` has been recreated.

To undo:

```bash
ssh $ADDR 'sudo systemctl stop minecraft-server-glade'
ssh $ADDR 'sudo rm -rf /srv/minecraft/glade/world/DIM1'
aws s3 cp s3://gastrodon-glade-ami/backups/glade-DIM1-<date>.tgz - \
  | ssh $ADDR 'sudo tar -C /srv/minecraft/glade/world -xzf -'
ssh $ADDR 'sudo systemctl start minecraft-server-glade'
```

### 7.7 — Post-deploy verification

```bash
ssh <server_address> 'systemctl status minecraft-server-glade; ss -Htln "sport = :25565"'
ssh <server_address> 'journalctl -u minecraft-server-glade | grep -iE "error|missing|caused by" | head -50'
ssh <server_address> 'ls /srv/minecraft/glade/mods | wc -l'
curl -sI "$(cd aws/minecraft && tofu output -raw client_pack_url)" | head -3
```

Then join, and check in-world: Aquamirae structures intact, carts gone as
expected, the End regenerated with YUNG's island shape (§7.6a), `/spark` for
tick health (view-distance 8 / sim 10 on c7a.2xlarge —
new mob mods are the thing most likely to move TPS; *Easy Mob Spawn Control* is
the lever if it does).

Give it ~15 minutes before declaring success — the `minecraft-glade-liveness`
watcher only intervenes after 600 s of "unit active but nothing on :25565", and
a first boot with 157 mods on cold EFS is genuinely slow.

### 7.8 — Commit

Follow the repo's existing commit style (see `4c43413`):

```
Update Glade modpack: 19 mod bumps, +17 mods (Hex addons, End overhaul,
ocean/aquatic set), drop Mobs Blocker + AstikorCarts + Obscure API

Icarus deliberately held at 2.13.2. Aquamirae 6.4.0 -> 7.1.11 moves it
off Obscure API onto Fragmentum. Better End was requested but has no
Forge 1.20.1 build and is broken under Connector (Sinytra/Connector#283).
```

---

## 8. Rollback

The AMI is content-addressed and the old one is not deleted, so rollback is a
launch-template pin:

```bash
# 1. fastest: point the launch template back at the previous AMI id (7.1) and
#    let the ASG refresh
aws ec2 create-launch-template-version --launch-template-name <name> \
  --source-version '$Latest' --launch-template-data '{"ImageId":"<old-ami>"}'
aws autoscaling start-instance-refresh --auto-scaling-group-name minecraft

# 2. clean: git revert the manifest commit and `tofu apply` — rebuilds the old
#    AMI bit-for-bit (same output hash → same S3 key → same AMI name)
```

If the **world** is the problem (R1), the AMI rollback is not enough — restore
the §7.1 backup onto EFS with the server stopped:

```bash
ssh <server_address> 'sudo systemctl stop minecraft-server-glade'
# restore, then start
```

The published client pack is keyed on the derivation hash, so reverting the
manifest also republishes the matching old `The_Glade.zip` automatically.

---

## 9. Open questions for the requester

All settled:

- ~~**Better End**~~ — **dropped** (§3.1).
- ~~**Nirvana**~~ — **CurseForge hemp/herb mod** (§3.2).
- ~~**Obscure API**~~ — **dropped**, orphan status verified post-build (§3.3, §10).
- ~~**YUNG's Better End Island / End reset**~~ — **reset the End** (§3.6, §7.6a).

Still assumed rather than asked, and cheap to reverse if either is wrong:

1. **Ocean's Enhancements** — 2024 alpha, single build, content overlaps Hybrid
   Aquatic (R6). Currently **included**; drop is a one-entry manifest edit.
2. **Cozy's Improved Wolves** — optional companion to Cozy's Improved Cats, not
   requested. Currently **not included**.

---

## 10. Build record — 2026-08-17

Status: **manifest + config implemented, all three artefacts built locally,
AMI image built. NOT deployed** — held at the requester's instruction pending
client-pack testing.

Branch: `glade-pack-2026-08`.

### What was changed

| file | change |
|---|---|
| `minecraft/pack/glade-mods.json` | 141 → **157** mods: 19 replaced, 3 removed, 19 added; `note` extended with the pin/floor warnings below |
| `minecraft/pack/config/astikorcarts-common.toml` | deleted (mod removed) |
| `minecraft/pack/config/Obscuria/**` | deleted, all 6 files (Aquamirae 6.x + Obscure API era) |

The manifest edit was applied by a script that asserts its own preconditions —
it refuses to run against anything but the exact 141-mod "before" state, checks
that no update is a no-op, that `side` never drifts, that Icarus still resolves
to `Icarus-Forge-2.13.2.jar`, that no filename collides, and that every entry
carries a hash. It reads the three JSON blocks **straight out of Appendix A of
this document**, so the plan and the manifest cannot drift.

Added to the manifest `note`, for whoever does the next bump:

> Icarus is deliberately held at 2.13.2 (2.14.0 exists — do not "fix" it on a
> routine bump). Forge 47.4.10 is a hard FLOOR: Fish 'N' Ships and Hybrid Blocks
> require `[47.4.10,)`. Geckolib is pinned from both sides by Aquamirae
> (`>=4.8.0`) and Devourer of Gods (`[4.8,5.0)`); PAUCAL is pinned by
> Hexal/MoreIotas to `[0.6.0,0.7.0)`. The Sophisticated
> Core/Backpacks/CreateIntegration trio must always move together.

### Artefacts built

| artefact | command | result |
|---|---|---|
| Client pack | `nix build .#gladeClient` | `result-glade-client/The_Glade.zip` — **562 MiB, 157 jars** |
| Server mod tree | `nix build --impure --expr '…glade-mods.nix…).server'` | `result-glade-server/mods/` — **148 jars** |
| System closure | `nix build .#nixosConfigurations.glade-aws.…toplevel` | ok |
| **AMI disk image** | `nix build .#amazonImage` | `result-ami-new/` — **3.75 GiB VHD**, 8 GiB logical |

New image store hash **`lbijqpbglqpbxck2dgzgk4kvcf7xqhz8`** (previous:
`8nbapmqs7shk2llw5qf9ajkcqqy69505`). That hash is what `build-ami.sh` turns into
the S3 key, snapshot description and AMI name, so `tofu apply` will register
**`minecraft-nixos-lbijqpbglqpbxck2dgzgk4kvcf7xqhz8`**. The image is already in
the local store and GC-rooted via `result-ami-new`, so the apply will reuse it
rather than rebuild — the slow part of the deploy is now only the S3 upload and
VM Import.

Size prediction vs actual: predicted ~545 MiB for the client zip, actual 562 MiB
(+138 MiB over the old 424 MiB). Image grew 3.6 → 3.75 GiB, comfortably inside
the 8 GiB image root.

### Verification performed

- ✅ **157 mods**, no duplicate filenames, every entry hashed, Icarus still 2.13.2.
- ✅ Server set is **148 jars**, exactly matching `side != "client"` in the manifest.
- ✅ Client zip contains **157 jars**.
- ✅ `astikorcarts` / `mobs_blocker` / `obscure_api` absent from the built tree.
- ✅ All 19 new jars present in the server tree.
- ✅ Config tree builds to **141 entries**; both `substituteInPlace
  --replace-fail` guards in `glade.nix` still matched (`maxRegions = 0`,
  `isHordeActiveWithNoPlayers = false`); `Obscuria/` and `astikorcarts-common.toml`
  confirmed absent from the built config.
- ✅ The Mutant More mixin patch still applied (its `jq -e` guard would have
  failed the build otherwise).

### Full-pack dependency audit

`META-INF/mods.toml` was extracted from all 148 server jars (139 have one; the
other 9 are Fabric jars running under Sinytra Connector, plus Kotlin for Forge,
which declares itself via `FMLModType: LIBRARY`). Parsing every `[[mods]]` and
mandatory `[[dependencies.*]]` block gives:

- **137 provided modIds, 306 mandatory dependency edges, 0 unsatisfied, 0 duplicate modIds.**

Five edges initially looked unsatisfied and were each run down to a **JarJar
nested provider**, not a gap:

| edge | provided by |
|---|---|
| `create → flywheel`, `create → ponder` | nested in `create-1.20.1-6.0.8.jar` |
| `PuzzlesLib → puzzlesaccessapi` | nested in `PuzzlesLib-v8.1.33.jar` |
| `Origins → connectormod` | nested in `Connector-1.0.0-beta.49.jar` |
| **`nirvana → kotlinforforge [4.0,)`** | `kotlinforforge-4.12.0-all.jar` (nested kfflang/kfflib/kffmod) ✓ 4.12.0 ≥ 4.0 |

The specific pins this change introduces all check out against the built tree:

```
geckolib     4.8.4   ← aquamirae wants [4.8.0,)   dog wants [4.8,5.0)   saintsdragons wants [4.8.1,)
paucal       0.6.0   ← hexal / moreiotas / hexcasting all want [0.6.0,0.7.0)
hexcasting   0.11.3  ← hexal + moreiotas want [0.11.1-6,)
patchouli    85      ← hexal + moreiotas want [1.20.1-80,)
moreiotas    0.1.2   ← hexal wants [0.1.1,)
fragmentum   1.5.2   ← aquamirae wants [1.5.2,)          ← exact floor, no headroom
yungsapi     4.0.6   ← yungsbetterendisland wants [1.20-Forge-4.0.1,)
```

> **Method note.** The first pass of this audit produced a *false pass*: the jars
> were addressed by relative path inside a `cd` subshell, so every extraction
> silently failed and nothing was actually checked. The second pass produced 15
> false *failures*, because the section regex didn't allow `[[mods]] #mandatory`
> trailing comments. Both were caught and fixed; the numbers above are from the
> corrected run. Worth knowing if this audit is ever re-run.

### Obscure API removal — evidence

The decision to drop it was verified, not assumed, against the **rebuilt** tree:
zero of the 139 `mods.toml` files reference `obscure_api`, and none of the 9
Fabric jars list it in `fabric.mod.json` `depends`. Aquamirae 7.1.11 depends on
`fragmentum` + `geckolib` only. Same check confirmed nothing depends on
`astikorcarts`.

### Not done (deliberately)

- ❌ **No deploy.** `tofu apply` not run; production still serves the old AMI and
  the old `The_Glade.zip`.
- ❌ **No staging instance** launched (§7.5).
- ❌ **No End reset** (§7.6a) — that is a post-deploy, server-stopped operation.
- ❌ **No world backup taken** (§7.1) — required before deploying, not before building.
- ⏭️ New mods' generated configs not yet vendored (§7.3); they will fall back to
  defaults, regenerated from the store on every restart, until captured from a
  staging boot.

### Next steps, in order

1. Test the client pack: import `result-glade-client/The_Glade.zip` into Prism.
2. §7.1 world backup + record the current AMI id.
3. §7.5 staging boot on a copy of the live world (Aquamirae 7 is the risk) and
   rehearse the End reset there.
4. §7.3 capture generated configs from staging, commit.
5. §7.6 `tofu apply`.
6. §7.6a reset the End.

---

## Appendix A — resolved manifest entries

Ready to paste into `minecraft/pack/glade-mods.json`. Every url was resolved
2026-08-17; Modrinth hashes come straight from the API, CurseForge sha1s were
computed from the downloaded jar (forgecdn serves no hashes).

**All 38 urls below were HEAD-verified live (HTTP 200) on 2026-08-17.** Filename
percent-encoding follows the existing manifest convention — space → `%20`,
`[`/`]` → `%5B`/`%5D`, `+` → `%2B`, `'` → `%27`.

### A.1 — Replacement entries for the 19 updated mods

Replace the matching object in `mods[]` wholesale (`name` is the join key; `side` is carried over unchanged).

```json
[
  {
    "name": "Aquamirae",
    "filename": "aquamirae-forge-1.20.1-7.1.11.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/k23mNPhZ/versions/22qc2xYZ/aquamirae-forge-1.20.1-7.1.11.jar",
    "sha1": "be9239b04d688d5e69aa49fda0a51f93788c3696",
    "sha512": "5edbf0a61b3dfe027d023185b465a09e6e83b1a9d6b02a797ac7581519b2de24208bc38f0c5dd94fa6a5f7ac1c5654917d2b32e85786b04c8182226ba402e808",
    "modrinth": "k23mNPhZ",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Companions!",
    "filename": "companions-forge-1.20.1-1.3.2.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/ArBFNu9T/versions/mJQe3orO/companions-forge-1.20.1-1.3.2.jar",
    "sha1": "4d87be4c44bb9fbf14bd7a8df2e9c695640d621f",
    "sha512": "cce2e6cd692bbd910168f3fbc6fad3627e3c30a71b64378977324fcfd95ab1e1cfcd9118f4359c30ba4347e9c2dd5915ab1ec707c70216e460ab69037606ae85",
    "modrinth": "ArBFNu9T",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Data Anchor",
    "filename": "Data_Anchor-forge-1.20.1-1.0.0.22.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/z2XEADmE/versions/xPqKwuPT/Data_Anchor-forge-1.20.1-1.0.0.22.jar",
    "sha1": "53d67aff56ed262abd45044758bf47967cd96948",
    "sha512": "5af7f5c1511f9926ca482c2f885e84aa89d68e16a44f4a43fb9c2b8b070bdcecaebf554b839f460afbcc670d9930c8d2a6d7f1e16175fffdfecb49508868a315",
    "modrinth": "z2XEADmE",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Forgified Fabric API",
    "filename": "fabric-api-0.92.6+1.11.15+1.20.1.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/Aqlf1Shp/versions/g0MxcWXy/fabric-api-0.92.6%2B1.11.15%2B1.20.1.jar",
    "sha1": "a37689ff8da8a32f82304ea4a1011873bb4c7eca",
    "sha512": "da1e59fa754edb24d8a3b6023ef648d6431a8297a9e873d18bfe866aca9384f491af1b438c2c4b75dbf9bd4b9a11daf717a8d1469e9efaed145e5c53f9cbcf37",
    "modrinth": "Aqlf1Shp",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Golem Overhaul",
    "filename": "golemoverhaul-forge-1.20.1-1.1.1.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/qEYs2G9A/versions/gcr95KrR/golemoverhaul-forge-1.20.1-1.1.1.jar",
    "sha1": "6a1cae93681c9ddba16143abef3238e0ead40475",
    "sha512": "17be147982a6b48c14ba71c92d1880193a3287376d3b1ca3ccbb9df55927348fddc34a727b6c959b5f5f52b43b5e08752f0fc604c3f5faefeee16e34aaf28636",
    "modrinth": "qEYs2G9A",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Hybrid Aquatic",
    "filename": "[1.20.1-Forge] Hybrid Aquatic 1.6.9.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/HH4FjUqN/versions/Uz0jRbE8/%5B1.20.1-Forge%5D%20Hybrid%20Aquatic%201.6.9.jar",
    "sha1": "22a0cf4bffd895dd66964a48bb2dbb46e91f8861",
    "sha512": "86a7399161b276b54a70116ca4f1506671d913fa9f68e404f041f44bdb4053e7bb7f85b1f06aef12e8c67e05c949aaff730a0e7ba2457be836b40ee730131749",
    "modrinth": "HH4FjUqN",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Just Enough Items (JEI)",
    "filename": "jei-1.20.1-forge-15.49.0.188.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/u6dRKJwZ/versions/hVXQAD0D/jei-1.20.1-forge-15.49.0.188.jar",
    "sha1": "21f781835beac0d638d8a27049e93c56d166b3dc",
    "sha512": "7e7b26379f43a76c091697be92ba4ebd059be4c5fc8a60f1e93a2092002097ce47ad5245ef35fb37b123bb61a0e6d3a96ba4aac9ef3b013fc7a6954577d9a2e5",
    "modrinth": "u6dRKJwZ",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Lost Trinkets Renewed",
    "filename": "LostTrinkets-20.1.4-mc1.20.1-forge.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/YXvTD5Ha/versions/kEAKzCsv/LostTrinkets-20.1.4-mc1.20.1-forge.jar",
    "sha1": "9ca3cb0e80895234f21c3b7544bf30482dd5000e",
    "sha512": "f5cc4cb363306f8dce051dd1b4d0e1107f17646836fc0e82707a04eab6b3d942662d0c8285097bffd6101b6d8c6a158bc9ce58da4c1d1fea0f5d5c093997c9fa",
    "modrinth": "YXvTD5Ha",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "More Critters",
    "filename": "More Critters 1.4.5.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/iRZ6t3qQ/versions/XVv1elXV/More%20Critters%201.4.5.jar",
    "sha1": "dec60b76d2cfb70402048e87274699c724eea602",
    "sha512": "b0281469d4f43d3b8080152a3046ac6e6a31e4b709d8b00f80e901afb3b7da7bf1f9ea1e6e37e370b785f6982dec2a825ce12cc52df3fcdd017b06ee5f50ab72",
    "modrinth": "iRZ6t3qQ",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "OneKeyMiner",
    "filename": "onekeyminer-forge-1.6.9-1.20.1.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/LZu4H9cp/versions/sxJZNGBj/onekeyminer-forge-1.6.9-1.20.1.jar",
    "sha1": "46b8833f5edfe0f06836c294d8e4fc9238a2a046",
    "sha512": "0aa9a7c9051c1a2102430b1667c118a94f6b76d3e966942688a6b319e20938e136afd829b8d11a3083a6a7273dcea31a8202afec1eb37e86e877961be8d6ba7b",
    "modrinth": "LZu4H9cp",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Roundabout: The JoJo Mod",
    "filename": "Roundabout-forge-1.20.1-3.4.4.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/IDI5Ie1o/versions/nwDbeztS/Roundabout-forge-1.20.1-3.4.4.jar",
    "sha1": "1040e04929cf6809470d7f87cff24b26f4ecd25e",
    "sha512": "4b5dbfa724ba71fbc7fbef301549133458a55db704c1f9e7c4c972f534501424a54d5888fb667357b0ead277e26bf1a997784b99ae87a29f4ffddc40812fe5f3",
    "modrinth": "IDI5Ie1o",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Saint's Dragons",
    "filename": "saintsdragons-0.9.3+forge-1.20.1.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/rjcsjwEU/versions/1Mjlec0M/saintsdragons-0.9.3%2Bforge-1.20.1.jar",
    "sha1": "3ac113a6175173ef228caa71d60e34a29af84e53",
    "sha512": "087feafe66274964aa545a2beb53678c17a7f08b04fb9e48783448f69878057423b6a06d661f5d413ad3a073ee4218fa7f7dd094df8e33a42061057f4e5ffe00",
    "modrinth": "rjcsjwEU",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Simple Voice Chat",
    "filename": "voicechat-forge-1.20.1-2.6.22.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/9eGKb6K1/versions/S11m0QIb/voicechat-forge-1.20.1-2.6.22.jar",
    "sha1": "ad9179e30cb7b3ffb42b3d9b8e2e9408b473d7fa",
    "sha512": "23c8b3a593fe506af8d8e0edc0afb45349777d5cdea41ffc3fa99afc2e3b9bc7770bb9951f674017ea5b3c23e111b0c6031ebd61820c9a0b5191e3992d9c8798",
    "modrinth": "9eGKb6K1",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Sophisticated Backpacks",
    "filename": "sophisticatedbackpacks-1.20.1-3.24.66.2095.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/TyCTlI4b/versions/iwTlYTI7/sophisticatedbackpacks-1.20.1-3.24.66.2095.jar",
    "sha1": "94b6fa551df12466f3ee5c8e38af0e31914e0e19",
    "sha512": "00acd23c0170f7f6600840c3f1f04e5c8b72f49f768fb5f25121ac0f99d2e69a3a3ed1ca98976eb363f73d52c9796976b8eeecc8d4067e00160b6509a3d43123",
    "modrinth": "TyCTlI4b",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Sophisticated Backpacks Create Integration",
    "filename": "sophisticatedbackpackscreateintegration-1.20.1-0.1.9.151.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/s85zLEDe/versions/iqMMWQF6/sophisticatedbackpackscreateintegration-1.20.1-0.1.9.151.jar",
    "sha1": "b6e9a0ca28321f88c99c30b7e908a2354f9118d6",
    "sha512": "721a3a1724deafe91fb308e9d4ecb0efb5074d211c0dc4024351037e6c3ade991c66fb5a8d799f1b3485ce6acc567698d020e573fb9d23247e691a7f30cf1aa5",
    "modrinth": "s85zLEDe",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Sophisticated Core",
    "filename": "sophisticatedcore-1.20.1-1.3.80.2267.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/nmoqTijg/versions/JKiEYolS/sophisticatedcore-1.20.1-1.3.80.2267.jar",
    "sha1": "59a92facf993e4e9f8be1e6cdc20b1c91dd0fd6f",
    "sha512": "da0530b033a15df7a9c3e4e465e6fa5466fbff529b939946414ec35584f303647dea55589d202c32635c8f78682207561d5c81bd3a775c064e5efc77e65e68e6",
    "modrinth": "nmoqTijg",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Via Romana: Infrastructure-Driven Fast Travel",
    "filename": "via_romana-2.2.3+1.20.1-forge.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/FVToiKwr/versions/vIdX4XS9/via_romana-2.2.3%2B1.20.1-forge.jar",
    "sha1": "7a86fc66d23668a896e12468cae4a19c96e66291",
    "sha512": "fe495c54efd40c09ebda10a889f7c677cc367f4330576e658e1a0993f68e94f3a2ffd9771e06a8d55373b08728dc87a3bb98a57318dea5513c8ef7f32a904ab9",
    "modrinth": "FVToiKwr",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Whaleborne",
    "filename": "whaleborne-1.20.1-1.2.4b.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/dyFCSxic/versions/MsrkdChD/whaleborne-1.20.1-1.2.4b.jar",
    "sha1": "9213bfac5891a3826d13d0ddfe383a366022674c",
    "sha512": "5026ca58a75ed8bdc70bb2a6f6388f6071d96cef383efc534e0f53aa18b0aff02639a14d53e8597df7dcae9710051ec232989aae13f2717c09ca434f743774e6",
    "modrinth": "dyFCSxic",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Skarrier Mobs",
    "filename": "skarrier_mobs-1.0.6-forge-1.20.1.jar",
    "side": "server",
    "source": "curseforge",
    "url": "https://mediafilez.forgecdn.net/files/8640/743/skarrier_mobs-1.0.6-forge-1.20.1.jar",
    "sha1": "4b6ed1c7c8884a0e2370512909481af78c0bd1d5",
    "sha512": null,
    "modrinth": null,
    "curseforge": {
      "projectId": 1566041,
      "fileId": 8640743
    }
  }
]
```

### A.2 — New entries for the 17 added mods

```json
[
  {
    "name": "Call From The Depths",
    "filename": "callfromthedepth_-3.7.7.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/oeL19pc1/versions/yE3suphg/callfromthedepth_-3.7.7.jar",
    "sha1": "a4f67b3068dcafbbabe9a4da6901ac98d128f2f4",
    "sha512": "61f766c8748210496175f3223a79f9cbff19bec753e91a65d4f23124668bcb0171900915036069c87ba20d392e039e99f5acefca440b2b4d7d0e3a3a7bdcd88e",
    "modrinth": "oeL19pc1",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Cozy's Improved Cats",
    "filename": "cozys-improved-cats-1.3.0-forge-1.20.1.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/5MaZBjPT/versions/xeA7oZv5/cozys-improved-cats-1.3.0-forge-1.20.1.jar",
    "sha1": "f1599d8c58db3e003aaa2dbb9f0ddfd52812976a",
    "sha512": "25176bf03f470dab4ec716f846b7b4e2ebe44efdf8deb903336bed83af160f76603bfdf13c7d4d6219ad844f2645ed5569a1ddfa316e9ba251fbb23d51523a6b",
    "modrinth": "5MaZBjPT",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Creator Comes Early (Even More Music Discs)",
    "filename": "creatorcomesearly-1.0.1-forge-1.20.1.jar",
    "side": "both",
    "source": "curseforge",
    "url": "https://mediafilez.forgecdn.net/files/5537/331/creatorcomesearly-1.0.1-forge-1.20.1.jar",
    "sha1": "023a00c181ea34d679dfb4e78ae0d64c47ad6fce",
    "sha512": null,
    "modrinth": null,
    "curseforge": {
      "projectId": 1064936,
      "fileId": 5537331
    }
  },
  {
    "name": "Devourer of Gods",
    "filename": "dog-1.1.0.jar",
    "side": "both",
    "source": "curseforge",
    "url": "https://mediafilez.forgecdn.net/files/8549/326/dog-1.1.0.jar",
    "sha1": "8be9a8b2d5e1e0d14c40dec2eac9f4526d6e5aa8",
    "sha512": null,
    "modrinth": null,
    "curseforge": {
      "projectId": 1630975,
      "fileId": 8549326
    }
  },
  {
    "name": "Easy Mob Spawn Control",
    "filename": "easy_mob_spawn_control-1.5.6.jar",
    "side": "server",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/pTXV6gwq/versions/I7m9NrGf/easy_mob_spawn_control-1.5.6.jar",
    "sha1": "fa36e9092ad31ea45483a212936461bd0f75366a",
    "sha512": "eec7d4a076b5b6cd5b474a083c9ff0d965d356fa55c19644c454f997b7de44f94a12f335146241ddd1dcc466cf6c1e08e8f9c1db7bfe8742cbc08e6cc9a36b4f",
    "modrinth": "pTXV6gwq",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "End Remastered",
    "filename": "endrem_forge-5.3.3-R-1.20.1.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/ZJTGwAND/versions/SQS2aSUl/endrem_forge-5.3.3-R-1.20.1.jar",
    "sha1": "b4df41de8439e834a493fe59842709ef33ecfa82",
    "sha512": "92aac4b5af4d69708ca2661cc628ab9a5f0f4b352601944451d3eaa1a46411b9dbfb312957a84a0b196550f9d9f1446acbc0c47e6d0a0279f1ff9df005f96438",
    "modrinth": "ZJTGwAND",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Fish 'N' Ships",
    "filename": "[1.20.1-Forge] Fish N' Ships 1.0.0.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/dBB5hLnG/versions/VGteEal1/%5B1.20.1-Forge%5D%20Fish%20N%27%20Ships%201.0.0.jar",
    "sha1": "04ef2fb2ebd68f80bea74ccb855c5e25ab01c0f2",
    "sha512": "04df3be9204909c2d81e4ef7adcd93f3a05eb6e85ba3d5ae2e7e05495eb490bc52dac0beb8022d82ac213f70731536a938f8cc514bbdd96e5dc4112ed43d9756",
    "modrinth": "dBB5hLnG",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Fragmentum",
    "filename": "fragmentum-forge-1.20.1-1.5.2.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/49C5QgTK/versions/1nysmgB4/fragmentum-forge-1.20.1-1.5.2.jar",
    "sha1": "d90de61cab08194a606246f1ac7677cebfcb7c59",
    "sha512": "23a0010ea6ebff893d5a8324fbe2d3be167d1263e6f84deadf7c4577132abb88b34fe88647d062acb0802468f5027f234e27a4b53c179cfb0f438f52a1942514",
    "modrinth": "49C5QgTK",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Hexal",
    "filename": "hexal-forge-1.20.1-0.3.1.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/aBVJ6Q36/versions/PmrRTYFS/hexal-forge-1.20.1-0.3.1.jar",
    "sha1": "1e3f626f69c42af49080abe32fa5085f6e0cb661",
    "sha512": "231c9d6f0acc0ce5067dbb50ead4a2d87bbc2bafb1385c051d6a4e6061e7651da78df48c6c875a035bbc9c46c0da6482e3ece1de883176b1b3517c8bbe9455ee",
    "modrinth": "aBVJ6Q36",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Hybrid Blocks",
    "filename": "[1.20 Forge] Hybrid Blocks 1.3.0.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/61Q9LmD0/versions/6Cs8Ft8Q/%5B1.20%20Forge%5D%20Hybrid%20Blocks%201.3.0.jar",
    "sha1": "dd9b2d7dde2e58dc146308ddf59b32f915a327d4",
    "sha512": "39f0b32b1cd56b2a853fa4b922836a00edc7cd1efc41e32f110b37fe8a73fb455179545812da0b951f6f72e2d53069c5115c9f39b8278f04532e30891d471a20",
    "modrinth": "61Q9LmD0",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Hybrid Delights",
    "filename": "[1.20.1-Forge] Hybrid Delights 1.2.1.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/WR49BBCu/versions/cAC1mkS5/%5B1.20.1-Forge%5D%20Hybrid%20Delights%201.2.1.jar",
    "sha1": "ec941ff204efca70cce920fd10ab0c81b8e9b273",
    "sha512": "c6b2868f01b9afa83af4a72747823b02c7157b097fa53e793b552fe22f13c605b366ba529c9150c6ff79d7f1c063e1f26d61c3c9d7262f053356594addec41e5",
    "modrinth": "WR49BBCu",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "MoreIotas",
    "filename": "moreiotas-forge-1.20.1-0.1.2.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/Jmt7p37B/versions/CEgmhGUx/moreiotas-forge-1.20.1-0.1.2.jar",
    "sha1": "6bb7e6af2b46a9024872efefd382425ef20d0faa",
    "sha512": "dd4b1ae29cb98492ac643ae92f5e2b0b578151b150cf7c30d3db9a913886752a1afb512fbc2ef6ca43c1e55788d78b0f6c8c1e4d5fe44c30dd5944e7acb50de4",
    "modrinth": "Jmt7p37B",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Mystic Seas",
    "filename": "mysticseas-1.1.0-forge-1.20.1.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/fmYbzjGG/versions/r9q7hVks/mysticseas-1.1.0-forge-1.20.1.jar",
    "sha1": "3676bbe5f4ffd14bf87d69f5e71c4ce7229aa76a",
    "sha512": "8917b715415450b019a9e8fd4505dbcce5a194c971f60512e70cce4d598430722dfefc66a27dd5a7d73feeec259bdacf5dfe6d228de4b0c6e119628d1bb8d21d",
    "modrinth": "fmYbzjGG",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Nirvana",
    "filename": "nirvana-forge-1.2.5.jar",
    "side": "both",
    "source": "curseforge",
    "url": "https://mediafilez.forgecdn.net/files/7766/58/nirvana-forge-1.2.5.jar",
    "sha1": "19137093cfdbb3bc71b74c39b6697c9ed5e1224e",
    "sha512": null,
    "modrinth": null,
    "curseforge": {
      "projectId": 1278909,
      "fileId": 7766058
    }
  },
  {
    "name": "Ocean's Enhancements",
    "filename": "oceans_enhancements-1.0.0-forge-1.20.1.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/guq90zGR/versions/OUHnfRgo/oceans_enhancements-1.0.0-forge-1.20.1.jar",
    "sha1": "44c96aaeb62b2f4679d9d64d0090eea4b3ce8b94",
    "sha512": "d2ab358be7aaa61151949ae7cb7b0ef3a267000031826429ad1e5a1f424b6e978498be6d0099a92b1e564ae733849cacacd10aaded2158fc3687eff223acc62c",
    "modrinth": "guq90zGR",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Sketchy Books",
    "filename": "sketchy_books-forge-1.20.1-1.1.0.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/Cuw1AXG3/versions/i1C8kfrh/sketchy_books-forge-1.20.1-1.1.0.jar",
    "sha1": "d7c8e3ff367c373bd614dd2775e35a225132604c",
    "sha512": "efce45d48a164d9cce6579a820e434d5a3994875b954087966971ec8d9bc9c3e3e3a6eb3fa91ada527ce6bc53a09c93ed86061db972794fc4be2a4034f7a556d",
    "modrinth": "Cuw1AXG3",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "YUNG's Better End Island",
    "filename": "YungsBetterEndIsland-1.20-Forge-2.0.6.jar",
    "side": "server",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/2BwBOmBQ/versions/Izqhg3Va/YungsBetterEndIsland-1.20-Forge-2.0.6.jar",
    "sha1": "4e7bf109981593061b8100bc8bf23e1c9bbcbb76",
    "sha512": "a51b76fc41d19276bea2ebe081b153d3be53c502ef9de93593990f8b7bf644e3e4fd4cff17477abce16692f23aff3077be1762606f10ca1058771741ad652e2e",
    "modrinth": "2BwBOmBQ",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  }
]
```

### A.3 — New entries for the 2 transitive dependencies

```json
[
  {
    "name": "YUNG's API",
    "filename": "YungsApi-1.20-Forge-4.0.6.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/Ua7DFN59/versions/PJOYAmAs/YungsApi-1.20-Forge-4.0.6.jar",
    "sha1": "af584b690f5646c6032002b58abc4591beed3833",
    "sha512": "7d83d94a90e55a712f6508485c044ff202916e9b9b9166b75177cb8f2eb919543bbbe1547d11c41cfd4763820f934235f47c0b26dd9e89bc1030954afa9fb889",
    "modrinth": "Ua7DFN59",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  },
  {
    "name": "Kleiders Custom Renderer API",
    "filename": "kleiders_custom_renderer-7.4.1-forge-1.20.1.jar",
    "side": "both",
    "source": "modrinth",
    "url": "https://cdn.modrinth.com/data/oaG6aa1j/versions/u7GegV7U/kleiders_custom_renderer-7.4.1-forge-1.20.1.jar",
    "sha1": "9f0f94ed3dd661b542e92d10aa40c8426117b36c",
    "sha512": "9151ff1a299cbc459452f3d48a8856898293a8276edaae8582c0fb9c3127153ad9af06d8843102167fcb2a468e132da71ae1dbebc38c3c300337f7e8b027fc48",
    "modrinth": "oaG6aa1j",
    "curseforge": {
      "projectId": null,
      "fileId": null
    }
  }
]
```
