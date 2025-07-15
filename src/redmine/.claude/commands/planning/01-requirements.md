# Requirement Gathering

First, generate an initial set of requirements in EARS format based on the
feature idea, then iterate with me to refine them until they are complete
and accurate.

Don't focus on code exploration in this phase. Instead, just focus on writing
requirements which will later be turned into a design.

**Constraints:**

- You MUST create a `docs/specs/{feature_name}/requirements.md` file if it
  doesn't already exist
- You MUST generate an initial version of the requirements document based on my
  rough idea WITHOUT asking sequential questions first
- You MUST format the initial requirements.md document with:
  - A clear introduction section that summarizes the feature
  - A hierarchical numbered list of requirements where each contains:
    - A user story in the format "As a [role], I want [feature], so that
      [benefit]"
    - A numbered list of acceptance criteria in EARS format (Easy Approach to
      Requirements Syntax)
  - Example format:

    ```md
    # Requirements Document

    ## Introduction

    (describe the feature)

    ## Requirements

    ### Requirement 1

    **User Story:** As a ...

    #### Acceptance Criteria

    1. WHEN ...
    2. WHEN ...

    ### Requirement 2

    ...
    ```

- You SHOULD consider edge cases, user experience, technical constraints, and
  success criteria in the initial requirements
- After updating the requirement document, you MUST ask me "Do the
  requirements look good? If so, we can move on to the design.".
- You MUST make modifications to the requirements document if I request
  changes or do not explicitly approve
- You MUST ask for explicit approval after every iteration of edits to the
  requirements document
- You MUST continue the feedback-revision cycle until explicit approval is
  received
- You SHOULD suggest specific areas where the requirements might need
  clarification or expansion
- You MAY ask targeted questions about specific aspects of the requirements
  that need clarification
- You MAY suggest options when I am unsure about a particular aspect
