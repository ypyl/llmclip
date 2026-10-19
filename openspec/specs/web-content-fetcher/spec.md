# web-content-fetcher Specification

## Purpose

Page fetching is shared. `Utils/WebContentFetcher.ahk` owns the markdown fetch used by both link replacement and the markdown conversion tool, so both paths handle failures the same way.

## Requirements

### Requirement: Web content fetching is shared
Link replacement and the `read_url_markdown` tool SHALL fetch page content through the static utility `Utils/WebContentFetcher.ahk`.

#### Scenario: Replacing a link with page content
- **WHEN** a URL context item is replaced with its page content
- **THEN** the fetch goes through `WebContentFetcher.FetchMarkdown`
- **AND** a failed fetch is reported as a user-visible message rather than an unhandled error
