## ADDED Requirements

### Requirement: Image context displayed as separate history row
The system SHALL display a separate clickable row in the chat history ListView when a user message includes attached images as context, using the same 📎 row pattern already used for text context.

#### Scenario: Image-only context produces a context row
- **WHEN** a user sends a message with one or more checked images as context and no text context
- **THEN** the history ListView SHALL show a 📎 row before the user message row
- **AND** the 📎 row label SHALL indicate the number of attached images (e.g., "📎 🖼️ 2 image(s) attached")

#### Scenario: Mixed text and image context produces a single context row
- **WHEN** a user sends a message with both checked text items and checked images as context
- **THEN** the history ListView SHALL show a single 📎 row before the user message row
- **AND** the 📎 row label SHALL indicate counts for both text items and images

#### Scenario: No context produces no context row (unchanged)
- **WHEN** a user sends a message with no context items (neither text nor images)
- **THEN** no 📎 row SHALL appear in the history ListView
- **AND** only the 👤 user message row SHALL be shown

### Requirement: Clicking image context row renders images in WebView
The system SHALL render the actual image content in the WebView when the user clicks the 📎 context row for a message containing image context.

#### Scenario: Clicking image-only context row shows images
- **WHEN** the user clicks a 📎 context row that was created for image-only context
- **THEN** the WebView SHALL display each attached image as a visible `<img>` element
- **AND** each image SHALL be rendered using a base64 data URI in markdown format (`![Image](data:image/<type>;base64,<data>)`)

#### Scenario: Clicking mixed context row shows text and images
- **WHEN** the user clicks a 📎 context row that was created for mixed text+image context
- **THEN** the WebView SHALL display the text context content as markdown
- **AND** the WebView SHALL display each attached image below the text context

#### Scenario: Clicking context row for message with no images shows text only (unchanged)
- **WHEN** the user clicks a 📎 context row that was created for text-only context
- **THEN** the WebView SHALL display the context text as markdown
- **AND** no image rendering SHALL be attempted

### Requirement: User message row excludes image context from preview
The system SHALL exclude image-related content from the user message row in the history ListView when images are treated as context. The user message row SHALL show only the user's typed prompt text.

#### Scenario: User message row shows prompt text without image suffix
- **WHEN** a user sends a message with image context and a typed prompt
- **THEN** the 👤 user message row SHALL display the user's typed prompt text
- **AND** the row SHALL NOT display an "[Image]" suffix or any image-related text

#### Scenario: User message row is empty when only images are sent
- **WHEN** a user sends a message with only image context (no typed prompt text)
- **THEN** the 👤 user message row SHALL display "(empty message)" or equivalent placeholder
