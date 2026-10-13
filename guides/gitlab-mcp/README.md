# GitLab MCP server (self-hosted GitLab)

| Field | Value |
|---|---|
| Tool | [`@zereight/mcp-gitlab`](https://www.npmjs.com/package/@zereight/mcp-gitlab) - MCP server for GitLab |
| Method | Run on demand with `npx`; no global install |
| Admin needed | No (needs Node.js/npm available to the user, e.g. via a per-user Node install such as `fnm` or `nvm`) |
| Audience | Coding agents (Claude Code or any MCP-compatible agent) and the engineers configuring them |

This guide tells an agent how to configure and use a GitLab MCP server for a self-hosted GitLab instance. Follow it when a user asks to "set up GitLab MCP", "connect to GitLab", or "read pipeline logs via MCP".

## 1. Purpose

The server gives an agent structured access to a self-hosted GitLab instance: pipelines, jobs, job logs/traces, artifacts, deployments, environments and pipeline schedules, without scraping the web UI or shelling out to `curl`/`glab`.

Primary use case: **reading CI/CD job logs** to diagnose failed builds and deploys.

## 2. Pick one server name and keep it

Choose one server key, for example `gitlab-selfhosted`, and use exactly that key on every machine in your team.

Why it matters:

- MCP tool names are namespaced by the server key, e.g. `mcp__gitlab-selfhosted__get_pipeline_job_output`. Any shared runbook, skill or script that calls a tool by name breaks silently if the local key differs.
- Some agents ship a plugin server already registered as `gitlab` that points at GitLab.com, not your self-hosted instance. Reusing that name, or one easily confused with it, makes agents call the wrong instance without an obvious error.

If a local config already uses a different key for the same instance, rename it rather than adding a second entry.

## 3. Server configuration

Add this block to the MCP configuration (for Claude Code: the `mcpServers` object in `~/.claude.json`; other agents use their own MCP config location):

```json
{
  "mcpServers": {
    "gitlab-selfhosted": {
      "command": "npx",
      "args": ["-y", "@zereight/mcp-gitlab"],
      "env": {
        "GITLAB_API_URL": "https://<gitlab-host>/api/v4",
        "GITLAB_PERSONAL_ACCESS_TOKEN": "<PASTE_YOUR_TOKEN_HERE>",
        "GITLAB_TOOLSETS": "pipelines"
      }
    }
  }
}
```

Notes for the agent applying this config:

- `GITLAB_API_URL` must be the API root of the self-hosted instance, `https://<gitlab-host>/api/v4`. Ask the user for the host if it is not known - never guess or reuse an example domain.
- `GITLAB_PERSONAL_ACCESS_TOKEN` is supplied by the user. **Never generate, guess or fabricate a token.** Never ask the user to paste it into chat - they edit the config file directly (see section 5).
- `GITLAB_TOOLSETS` limits which tool groups the server exposes:
  - `pipelines` - pipelines, jobs, job logs, artifacts, deployments, environments, schedules. Enough for CI/CD log reading.
  - Add others (`merge_requests`, `issues`, `repository`, ...) as a comma-separated list only when the task needs them. A narrower toolset is a narrower blast radius if the token or the agent misbehaves.
- Put the token only in `env`, never in `args`: `args` can be visible to other users through the process list.
- After editing the config, **fully restart** the agent session (not just an in-session MCP reload). Tell the user this explicitly.

## 4. Least-privilege personal access token

Guide the user to the **legacy token** page (**User Settings -> Access Tokens -> Personal access tokens -> Generate token -> Legacy token**; labels vary between GitLab versions) and to select only the scopes the task needs:

| Task | Minimum scope | Avoid |
|---|---|---|
| Read pipelines, jobs, logs, artifacts, deployments, environments | `read_api` | `api` (full read/write), `write_repository`, `read_repository` (job logs come through the API, not Git over HTTP) |
| Trigger, retry, cancel or play pipelines/jobs | `api` (no narrower scope covers CI/CD writes) | Granting it by default; only when the task explicitly needs writes |

Guidance to give every time:

1. **Default to `read_api` alone.** It covers every read-only pipeline, job, log and artifact operation. It grants read access to everything the user can already see, and no write access.
2. **Never select `api` unless the task needs writes** (retrying a job, creating a pipeline, playing a manual job). `api` grants read/write across all groups and projects, the container registry and the package registry.
3. **Never select unrelated scopes** (`read_registry`, `create_runner`, `manage_runner`, `k8s_proxy`, `ai_features`, ...) just because they are on the form.
4. **Always set an expiration date.** A narrow token that never expires is still a standing credential. When it expires the MCP server stops connecting; the fix is a new token and a config update.
5. **The token is shown once.** Copy it straight into a password manager or the MCP config file - never into chat, a shared document, a commit or a guide.
6. Adding write access later is a **separate, deliberate scope upgrade** (new token or edited scopes), not a reason to pick `api` "to be safe".

## 5. Handling the token (agent behavior)

- Never ask for the token in the conversation. Never echo, log, print or write it into any file the agent creates.
- Never commit a config containing a real token. Example configs in a repository use an obvious placeholder (`<PASTE_YOUR_TOKEN_HERE>`); the real value lives only in a local, untracked config.
- If a user pastes something that looks like a live token into chat, point it out, do not repeat it, and tell them to revoke and rotate it.
- When editing config for the user, write the placeholder and let the user fill in the real value in their editor.

## 6. Verify the connection

After the user restarts the agent session:

1. Confirm the server is connected (`/mcp` in Claude Code, or the agent's equivalent).
2. Confirm the tools appear under the chosen namespace, in particular `get_pipeline_job_output`. If they are missing, check:
   - the token placeholder was replaced with a real value;
   - the session was fully restarted;
   - the machine can reach the GitLab host and run `npx` (Node/npm installed, npm registry reachable);
   - `GITLAB_API_URL` ends in `/api/v4` and matches the real host.
3. Report the setup as working only after a tool call has succeeded against a real pipeline or job.

## 7. Using the tools

Typical flow for "get me the log of a failed job":

1. `list_pipelines` (or `get_pipeline` if the ID/ref is known) to find the pipeline.
2. `list_pipeline_jobs` to find the failed job.
3. `get_pipeline_job_output` with the job ID. Use its pagination options for long logs instead of pulling the whole trace into context.

The `pipelines` toolset also exposes lifecycle actions (`retry_pipeline`, `retry_pipeline_job`, `cancel_pipeline`, `cancel_pipeline_job`, `play_pipeline_job`, `create_pipeline`), artifacts (`list_job_artifacts`, `get_job_artifact_file`, `download_job_artifacts`), deployments and environments (`list_deployments`, `get_deployment`, `list_environments`, `get_environment`) and schedule management (`list_pipeline_schedules`, `get_pipeline_schedule`, `create_pipeline_schedule`, `update_pipeline_schedule`, `delete_pipeline_schedule` and their variable equivalents). Use write actions only when the user explicitly asks; default to read-only investigation.
