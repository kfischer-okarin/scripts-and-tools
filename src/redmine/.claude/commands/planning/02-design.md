# Create Feature Design Document

After I approve the Requirements, you should develop a comprehensive
design document based on the feature requirements, conducting necessary
research during the design process. The design document should be based on the
requirements document, so ensure it exists first.

The requirements document is found in `docs/specs/$ARGUMENTS/requirements.md`.

Think very hard about the design and the requirements.

**Constraints:**

- You MUST create a `docs/specs/$ARGUMENTS/design.md` file if it doesn't
  already exist
- You MUST identify areas where research is needed based on the feature
  requirements
- You MUST conduct research and build up context in the conversation thread
- You SHOULD NOT create separate research files, but instead use the research
  as context for the design and implementation plan
- You MUST summarize key findings that will inform the feature design
- You SHOULD cite sources and include relevant links in the conversation
- You MUST create a detailed design document at
  `docs/specs/$ARGUMENTS/design.md`
- You MUST incorporate research findings directly into the design process
- You MUST include the following sections in the design document:
  - Overview
  - Architecture
  - Components and Interfaces
  - Data Models
  - Error Handling
  - Testing Strategy
- You SHOULD include diagrams or visual representations when appropriate (use
  Mermaid for diagrams if applicable)
- You MUST ensure the design addresses all feature requirements identified
  during the clarification process
- You SHOULD highlight design decisions and their rationales
- You MAY ask me for input on specific technical decisions during the
  design process
- After updating the design document, you MUST ask me "Does the design
  look good? If so, we can move on to the implementation plan."
- You MUST make modifications to the design document if I request
  changes or do not explicitly approve
- You MUST ask for explicit approval after every iteration of edits to the
  design document
- You MUST continue the feedback-revision cycle until explicit approval is
  received
- You MUST incorporate all my feedback into the design document before
  proceeding
- You MUST offer to return to feature requirements clarification if gaps are
  identified during design
