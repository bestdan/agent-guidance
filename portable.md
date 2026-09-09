# Portable guidance

Sentinel payload. This file carries no real rule yet: the guidance plugin's
rails landed first, with one short rule per file, so that delivery to every
audience could be verified before anything worth losing moved. The real
portable half of `agents/AGENTS.md` arrives in plugin task 5 of
`dev_docs/tasks/guidance_plugin_plan/`.

Marker for the delivery tests: `GUIDANCE-SENTINEL-SHARED`.

- When a command fails, read its error text before retrying it.
