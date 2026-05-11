import DOMPurify from "dompurify"
import { marked } from "marked"

const HELP_PREVIEW_ALLOWED_TAGS = ["p", "br", "div", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "li", "strong", "em", "a", "code", "pre", "blockquote", "hr", "table", "thead", "tbody", "tr", "th", "td", "span", "u", "mark"]
const HELP_PREVIEW_ALLOWED_ATTRIBUTES = ["href", "title", "rel", "target", "class"]
const HELP_PREVIEW_ALLOWED_CLASSES = new Set([
  "help-md-font-sans",
  "help-md-font-serif",
  "help-md-font-display",
  "help-md-font-editorial",
  "help-md-size-sm",
  "help-md-size-md",
  "help-md-size-lg",
  "help-md-color-slate",
  "help-md-color-blue",
  "help-md-color-rose",
  "help-md-color-emerald",
  "help-md-highlight",
  "help-md-highlight--yellow",
  "help-md-highlight--green",
  "help-md-highlight--red"
])

const helpPreviewToggleIcon = (active = false) => {
  if (active) {
    return `
      <svg class="help-grid-block__icon-svg help-grid-block__icon-svg--eye" viewBox="0 0 12 10" fill="none" xmlns="http://www.w3.org/2000/svg" focusable="false">
        <path d="M0.8 5C2.05 2.2 3.9 1 6 1C8.1 1 9.95 2.2 11.2 5C9.95 7.8 8.1 9 6 9C3.9 9 2.05 7.8 0.8 5Z" stroke="currentColor" stroke-width="1.1" stroke-linecap="round" stroke-linejoin="round"/>
        <circle cx="6" cy="5" r="1.55" fill="currentColor"/>
        <path d="M1.7 8.3L10.3 1.7" stroke="currentColor" stroke-width="1.1" stroke-linecap="round"/>
      </svg>
    `
  }

  return `
    <svg class="help-grid-block__icon-svg help-grid-block__icon-svg--eye" viewBox="0 0 12 10" fill="none" xmlns="http://www.w3.org/2000/svg" focusable="false">
      <path d="M0.8 5C2.05 2.2 3.9 1 6 1C8.1 1 9.95 2.2 11.2 5C9.95 7.8 8.1 9 6 9C3.9 9 2.05 7.8 0.8 5Z" stroke="currentColor" stroke-width="1.1" stroke-linecap="round" stroke-linejoin="round"/>
      <circle cx="6" cy="5" r="1.55" fill="currentColor"/>
    </svg>
  `
}

const helpDeleteIcon = `
  <svg class="help-grid-block__icon-svg" viewBox="0 0 10 10" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true" focusable="false">
    <path d="M1 1L9 9" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"/>
    <path d="M9 1L1 9" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"/>
  </svg>
`

marked.use({ gfm: true, breaks: true })

const sanitizePreviewClasses = (root) => {
  root.querySelectorAll("[class]").forEach((element) => {
    const allowedClasses = Array.from(element.classList).filter((className) => HELP_PREVIEW_ALLOWED_CLASSES.has(className))

    if (allowedClasses.length > 0) {
      element.className = allowedClasses.join(" ")
      return
    }

    element.removeAttribute("class")
  })
}

const renderHelpMarkdown = (content) => {
  const rawHtml = marked.parse(content || "")
  const sanitizedHtml = DOMPurify.sanitize(rawHtml, {
    ALLOWED_TAGS: HELP_PREVIEW_ALLOWED_TAGS,
    ALLOWED_ATTR: HELP_PREVIEW_ALLOWED_ATTRIBUTES
  })
  const wrapper = document.createElement("div")

  wrapper.innerHTML = sanitizedHtml
  sanitizePreviewClasses(wrapper)
  wrapper.querySelectorAll("a[href]").forEach((link) => {
    link.setAttribute("rel", "nofollow noopener")
    link.setAttribute("target", "_blank")
  })

  return wrapper.innerHTML.trim()
}

const sanitizeHelpRichText = (content) => {
  const sanitizedHtml = DOMPurify.sanitize(content || "", {
    ALLOWED_TAGS: HELP_PREVIEW_ALLOWED_TAGS,
    ALLOWED_ATTR: HELP_PREVIEW_ALLOWED_ATTRIBUTES
  })
  const wrapper = document.createElement("div")

  wrapper.innerHTML = sanitizedHtml
  sanitizePreviewClasses(wrapper)
  wrapper.querySelectorAll("a[href]").forEach((link) => {
    link.setAttribute("rel", "nofollow noopener")
    link.setAttribute("target", "_blank")
  })

  return wrapper.innerHTML.trim()
}

const attachHelpGridEditors = () => {
  document.querySelectorAll("[data-help-grid-board]").forEach((board) => {
    if (board.dataset.helpGridBound === "true") {
      return
    }

    board.dataset.helpGridBound = "true"

    const configElement = document.querySelector("[data-help-editor-config]")
    const config = configElement ? JSON.parse(configElement.textContent) : null
    if (!config) {
      return
    }

    const columns = Number(board.dataset.columns || 4)
    const gap = Number(board.dataset.gap || 10)
    const clamp = (value, min, max) => Math.min(Math.max(value, min), max)
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    const pageStatus = document.querySelector("[data-help-page-status]")
    const addCardButton = document.querySelector("[data-help-add-card]")
    const saveDraftButton = document.querySelector("[data-help-save-draft]")
    const publishDraftButton = document.querySelector("[data-help-publish-draft]")
    const formatting = config.formatting || {}
    const measureScrollbarWidth = () => {
      const probe = document.createElement("div")

      probe.style.position = "absolute"
      probe.style.top = "-9999px"
      probe.style.width = "100px"
      probe.style.height = "100px"
      probe.style.overflow = "scroll"
      probe.style.pointerEvents = "none"
      document.body.append(probe)

      const width = Math.max(probe.offsetWidth - probe.clientWidth, 0)
      probe.remove()

      return width
    }
    const scrollbarWidth = measureScrollbarWidth()
    const syncBoardCellMetrics = (width = board.getBoundingClientRect().width) => {
      const cellSize = Math.max((width - (gap * (columns - 1))) / columns, 32)
      board.style.setProperty("--help-grid-cell-size", `${cellSize}px`)
      board.style.setProperty("--help-grid-row-size", `${cellSize}px`)
    }
    const resizeObserver = new ResizeObserver((entries) => {
      entries.forEach((entry) => {
        syncBoardCellMetrics(entry.contentRect.width)
      })
    })

    resizeObserver.observe(board)
    syncBoardCellMetrics()

    const readField = (form, name) => form.querySelector(`[data-help-grid-field="${name}"]`)
    const readBodyField = (form) => form.querySelector('[data-help-card-field="body"]')
    const readEditorField = (form) => form.querySelector('[data-help-card-editor]')
    const readPreviewToggle = (form) => form.querySelector("[data-help-preview-toggle]")
    const readPreviewPanel = (form) => form.querySelector("[data-help-card-preview]")
    const readPreviewBody = (form) => form.querySelector("[data-help-card-preview-body]")
    const readDeleteButton = (form) => form.querySelector("[data-help-delete-card]")
    const formatLabel = (template, replacements = {}) => Object.entries(replacements)
      .reduce((value, [key, replacement]) => value.replaceAll(`%{${key}}`, replacement), template)
    const formatTimestamp = (value) => {
      if (!value) {
        return null
      }

      return new Intl.DateTimeFormat(document.documentElement.lang || "pt-BR", {
        dateStyle: "short",
        timeStyle: "short"
      }).format(new Date(value))
    }
    const readValue = (form, name, fallback) => {
      const value = Number.parseInt(readField(form, name)?.value || fallback, 10)
      return Number.isFinite(value) ? value : fallback
    }

    const setPreviewToggleState = (button, active) => {
      if (!button) {
        return
      }

      button.dataset.previewActive = active ? "true" : "false"
      button.setAttribute("aria-label", active ? config.labels.hidePreview : config.labels.showPreview)

      const iconSlot = button.querySelector("[data-help-preview-icon]")
      if (iconSlot) {
        iconSlot.innerHTML = helpPreviewToggleIcon(active)
      }
    }

    const syncPreview = (form) => {
      const previewBody = readPreviewBody(form)
      if (!previewBody) {
        return
      }

      const renderedHtml = renderHelpMarkdown(readBodyField(form)?.value || "")
      previewBody.innerHTML = renderedHtml || `<p class="help-grid-block__preview-placeholder">${config.labels.previewEmpty}</p>`
    }

    const syncEditorFromBody = (form) => {
      const editor = readEditorField(form)
      if (!editor) {
        return
      }

      const renderedHtml = renderHelpMarkdown(readBodyField(form)?.value || "")
      editor.innerHTML = renderedHtml
    }

    const syncBodyFromEditor = (form) => {
      const editor = readEditorField(form)
      const bodyField = readBodyField(form)
      if (!editor || !bodyField) {
        return
      }

      const sanitizedHtml = sanitizeHelpRichText(editor.innerHTML)
      bodyField.value = sanitizedHtml
      editor.innerHTML = sanitizedHtml
    }

    const setPreviewMode = (form, active) => {
      form.dataset.previewMode = active ? "true" : "false"

      const editor = readEditorField(form)
      const previewPanel = readPreviewPanel(form)
      if (active) {
        syncBodyFromEditor(form)
        syncPreview(form)
      }

      if (editor) {
        editor.hidden = active
      }

      if (previewPanel) {
        previewPanel.hidden = !active
      }

      setPreviewToggleState(readPreviewToggle(form), active)
    }

    const syncScrollbarAlignment = (form) => {
      const deleteButton = readDeleteButton(form)
      if (!deleteButton) {
        return
      }

      const deleteWidth = Math.max(deleteButton.getBoundingClientRect().width, 0)

      form.style.setProperty("--help-grid-scrollbar-width", `${scrollbarWidth}px`)
      form.style.setProperty("--help-grid-delete-size", `${deleteWidth}px`)
    }

    const initializeForm = (form) => {
      syncFormLayout(form)
      syncScrollbarAlignment(form)
      syncEditorFromBody(form)
      syncPreview(form)
      setPreviewMode(form, false)
    }

    const buildSelectOptions = (items = []) => items.map((item) => `<option value="${item.value}">${item.label}</option>`).join("")
    const buildHighlightButtons = (items = []) => items.map((item) => `
      <button type="button" class="help-grid-format-menu__highlight" data-help-format-highlight="${item.value}" aria-label="${item.label}" title="${item.label}">
        <span class="help-grid-format-menu__highlight-swatch" style="background:${item.swatch}"></span>
        <span>${item.label}</span>
      </button>
    `).join("")

    const buildFormattingMenu = () => {
      const existingMenu = document.querySelector("[data-help-format-menu]")
      if (existingMenu) {
        return existingMenu
      }

      const menu = document.createElement("div")
      menu.className = "help-grid-format-menu"
      menu.dataset.helpFormatMenu = "true"
      menu.hidden = true
      menu.innerHTML = `
        <p class="help-grid-format-menu__title">${formatting.menuTitle}</p>
        <div class="help-grid-format-menu__fields">
          <label class="help-grid-format-menu__field">
            <span>${formatting.fontLabel}</span>
            <select data-help-format-select="font">
              <option value="">${formatting.chooseOption}</option>
              ${buildSelectOptions(formatting.fonts)}
            </select>
          </label>
          <label class="help-grid-format-menu__field">
            <span>${formatting.sizeLabel}</span>
            <select data-help-format-select="size">
              <option value="">${formatting.chooseOption}</option>
              ${buildSelectOptions(formatting.sizes)}
            </select>
          </label>
          <label class="help-grid-format-menu__field">
            <span>${formatting.colorLabel}</span>
            <select data-help-format-select="color">
              <option value="">${formatting.chooseOption}</option>
              ${buildSelectOptions(formatting.colors)}
            </select>
          </label>
        </div>
        <div class="help-grid-format-menu__field">
          <span>${formatting.highlightLabel}</span>
          <div class="help-grid-format-menu__highlights">
            ${buildHighlightButtons(formatting.highlights)}
          </div>
        </div>
      `

      document.body.append(menu)
      return menu
    }

    const formattingMenu = buildFormattingMenu()
    let activeFormattingTarget = null

    const closeFormattingMenu = () => {
      formattingMenu.hidden = true
      activeFormattingTarget = null
    }

    const captureEditorRange = (editor) => {
      const selection = window.getSelection()
      if (!selection || selection.rangeCount === 0) {
        return null
      }

      const range = selection.getRangeAt(0)
      const commonAncestor = range.commonAncestorContainer
      if (!editor.contains(commonAncestor.nodeType === Node.TEXT_NODE ? commonAncestor.parentNode : commonAncestor)) {
        return null
      }

      return range.cloneRange()
    }

    const setActiveFormattingTarget = (editor) => {
      activeFormattingTarget = {
        editor,
        range: captureEditorRange(editor)
      }
    }

    const positionFormattingMenu = (clientX, clientY) => {
      formattingMenu.hidden = false

      const menuRect = formattingMenu.getBoundingClientRect()
      const left = Math.min(clientX, window.innerWidth - menuRect.width - 16)
      const top = Math.min(clientY, window.innerHeight - menuRect.height - 16)

      formattingMenu.style.left = `${Math.max(left, 16)}px`
      formattingMenu.style.top = `${Math.max(top, 16)}px`
    }

    const withStoredSelection = (callback) => {
      if (!activeFormattingTarget?.editor || !activeFormattingTarget?.range) {
        return
      }

      const { editor, range } = activeFormattingTarget
      if (range.collapsed) {
        editor.focus()
        return
      }

      callback(editor, range.cloneRange())
    }

    const applyClassWrap = (className, tagName = "span") => {
      withStoredSelection((editor, range) => {
        const wrapper = document.createElement(tagName)
        if (tagName === "mark") {
          wrapper.className = `help-md-highlight ${className}`
        } else {
          wrapper.className = className
        }

        const fragment = range.extractContents()
        wrapper.append(fragment)
        range.insertNode(wrapper)

        const selection = window.getSelection()
        selection?.removeAllRanges()
        const updatedRange = document.createRange()
        updatedRange.selectNodeContents(wrapper)
        selection?.addRange(updatedRange)

        const form = editor.closest("[data-help-grid-item]")
        if (form) {
          syncBodyFromEditor(form)
          syncPreview(form)
          markLocalDraftDirty(config.labels.localDirty)
        }

        setActiveFormattingTarget(editor)
      })
    }

    formattingMenu.addEventListener("click", (event) => {
      const highlightButton = event.target.closest("[data-help-format-highlight]")
      if (highlightButton) {
        applyClassWrap(highlightButton.dataset.helpFormatHighlight, "mark")
      }
    })

    formattingMenu.addEventListener("change", (event) => {
      const select = event.target.closest("[data-help-format-select]")
      if (!select || !select.value) {
        return
      }

      if (select.dataset.helpFormatSelect === "font") {
        applyClassWrap(select.value)
      }

      if (select.dataset.helpFormatSelect === "size") {
        applyClassWrap(select.value)
      }

      if (select.dataset.helpFormatSelect === "color") {
        applyClassWrap(select.value)
      }

      select.value = ""
    })

    document.addEventListener("pointerdown", (event) => {
      if (formattingMenu.hidden) {
        return
      }

      if (event.target.closest("[data-help-format-menu]")) {
        return
      }

      closeFormattingMenu()
    })

    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape") {
        closeFormattingMenu()
      }
    })

    window.addEventListener("resize", closeFormattingMenu)

    const readLayout = (form) => ({
      columnStart: readValue(form, "column_start", 1),
      columnSpan: readValue(form, "column_span", 1),
      rowStart: readValue(form, "row_start", 1),
      rowSpan: readValue(form, "row_span", 1)
    })

    const syncFormLayout = (form) => {
      const columnStart = clamp(readValue(form, "column_start", 1), 1, columns)
      const columnSpan = clamp(readValue(form, "column_span", 1), 1, columns - columnStart + 1)
      const rowStart = Math.max(readValue(form, "row_start", 1), 1)
      const rowSpan = Math.max(readValue(form, "row_span", 1), 1)

      readField(form, "column_start").value = columnStart
      readField(form, "column_span").value = columnSpan
      readField(form, "row_start").value = rowStart
      readField(form, "row_span").value = rowSpan

      form.style.gridColumn = `${columnStart} / span ${columnSpan}`
      form.style.gridRow = `${rowStart} / span ${rowSpan}`
      syncScrollbarAlignment(form)
    }

    const applyLayout = (form, layout) => {
      readField(form, "column_start").value = layout.columnStart
      readField(form, "column_span").value = layout.columnSpan
      readField(form, "row_start").value = layout.rowStart
      readField(form, "row_span").value = layout.rowSpan

      syncFormLayout(form)
    }

    const updateBoardRowCount = () => {
      const rowCount = Array.from(board.querySelectorAll("[data-help-grid-item]"))
        .reduce((maxRows, form) => Math.max(maxRows, readValue(form, "row_start", 1) + readValue(form, "row_span", 1) - 1), 0)

      board.style.setProperty("--help-grid-row-count", Math.max(rowCount, 6))
    }

    const updatePageStatus = (text, state = "idle") => {
      if (!pageStatus) {
        return
      }

      pageStatus.textContent = text
      pageStatus.dataset.state = state
    }

    const storageKey = config.storageKey
    const readSessionDraft = () => {
      try {
        const rawValue = window.sessionStorage.getItem(storageKey)
        return rawValue ? JSON.parse(rawValue) : null
      } catch (_error) {
        window.sessionStorage.removeItem(storageKey)
        return null
      }
    }

    const writeSessionDraft = () => {
      const snapshot = {
        blocks: Array.from(board.querySelectorAll("[data-help-grid-item]")).map((form) => ({
          id: form.dataset.helpBlockId,
          body: readBodyField(form).value,
          style_variant: readField(form, "style_variant")?.value || "card",
          column_start: readValue(form, "column_start", 1),
          column_span: readValue(form, "column_span", 1),
          row_start: readValue(form, "row_start", 1),
          row_span: readValue(form, "row_span", 1)
        })),
        updated_at: new Date().toISOString()
      }

      window.sessionStorage.setItem(storageKey, JSON.stringify(snapshot))
      return snapshot
    }

    const buildEmptyState = () => {
      const emptyState = document.createElement("div")
      emptyState.className = "help-grid-empty-state"
      emptyState.innerHTML = `
        <div>
          <h2 class="h5 mb-2">${config.labels.emptyTitle}</h2>
          <p class="mb-0">${config.labels.emptyBody}</p>
        </div>
      `

      return emptyState
    }

    const ensureEmptyState = () => {
      const hasItems = board.querySelector("[data-help-grid-item]")
      const emptyState = board.querySelector(".help-grid-empty-state")

      if (hasItems && emptyState) {
        emptyState.remove()
      }

      if (!hasItems && !emptyState) {
        board.append(buildEmptyState())
      }
    }

    const buildBlockElement = (blockData) => {
      const form = document.createElement("form")
      form.className = "help-grid-block help-grid-block__form"
      form.id = `help-block-${blockData.id}`
      form.dataset.helpGridItem = "true"
      form.dataset.helpBlockId = blockData.id
      form.autocomplete = "off"
      form.innerHTML = `
        <span class="help-grid-block__resize-edge help-grid-block__resize-edge--top" data-help-resize-edge="top"></span>
        <span class="help-grid-block__resize-edge help-grid-block__resize-edge--right" data-help-resize-edge="right"></span>
        <span class="help-grid-block__resize-edge help-grid-block__resize-edge--bottom" data-help-resize-edge="bottom"></span>
        <span class="help-grid-block__resize-edge help-grid-block__resize-edge--left" data-help-resize-edge="left"></span>
        <span class="help-grid-block__resize-corner help-grid-block__resize-corner--top-left" data-help-resize-edge="top,left"></span>
        <span class="help-grid-block__resize-corner help-grid-block__resize-corner--top-right" data-help-resize-edge="top,right"></span>
        <span class="help-grid-block__resize-corner help-grid-block__resize-corner--bottom-right" data-help-resize-edge="bottom,right"></span>
        <span class="help-grid-block__resize-corner help-grid-block__resize-corner--bottom-left" data-help-resize-edge="bottom,left"></span>

        <input type="hidden" data-help-grid-field="style_variant">
        <input type="hidden" data-help-grid-field="column_start">
        <input type="hidden" data-help-grid-field="column_span">
        <input type="hidden" data-help-grid-field="row_start">
        <input type="hidden" data-help-grid-field="row_span">

        <div class="help-grid-block__controls">
          <button type="button" class="help-grid-block__preview-toggle" data-help-preview-toggle data-preview-active="false" aria-label="${config.labels.showPreview}">
            <span class="help-grid-block__icon-slot help-grid-block__icon-slot--eye" data-help-preview-icon aria-hidden="true">
              ${helpPreviewToggleIcon(false)}
            </span>
          </button>
          <span class="help-grid-block__drag-handle" data-help-move-handle role="button" tabindex="0" aria-label="${config.labels.move}">
            <span class="help-grid-block__drag-dots" aria-hidden="true">
              <span></span>
              <span></span>
              <span></span>
              <span></span>
            </span>
          </span>
          <button type="button" class="help-grid-block__delete" data-help-delete-card aria-label="${config.labels.delete}">
            ${helpDeleteIcon}
          </button>
        </div>

        <div class="help-grid-block__editor-surface">
          <textarea class="help-grid-block__textarea" data-help-card-field="body" rows="8" placeholder="${config.labels.bodyPlaceholder}"></textarea>
          <div class="help-grid-block__editor" data-help-card-editor contenteditable="true" role="textbox" aria-multiline="true" spellcheck="true" data-placeholder="${config.labels.bodyPlaceholder}"></div>
          <div class="help-grid-block__preview" data-help-card-preview hidden>
            <div class="help-grid-block__body help-grid-block__body--preview" data-help-card-preview-body></div>
          </div>
        </div>
      `

      readField(form, "style_variant").value = blockData.style_variant || "card"
      readField(form, "column_start").value = blockData.column_start
      readField(form, "column_span").value = blockData.column_span
      readField(form, "row_start").value = blockData.row_start
      readField(form, "row_span").value = blockData.row_span
      readBodyField(form).value = blockData.body
      initializeForm(form)

      return form
    }

    const renderBlocks = (blocks) => {
      board.replaceChildren()

      blocks.forEach((block) => {
        board.append(buildBlockElement(block))
      })

      ensureEmptyState()
      updateBoardRowCount()
    }

    const nextAvailableRow = () => Array.from(board.querySelectorAll("[data-help-grid-item]"))
      .reduce((maxRows, form) => Math.max(maxRows, readValue(form, "row_start", 1) + readValue(form, "row_span", 1) - 1), 0) + 1

    const createLocalId = () => {
      if (window.crypto?.randomUUID) {
        return `local-${window.crypto.randomUUID()}`
      }

      return `local-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`
    }

    const markLocalDraftDirty = (message = config.labels.localDirty) => {
      writeSessionDraft()
      ensureEmptyState()
      updateBoardRowCount()
      updatePageStatus(message, "dirty")
    }

    const restoreSessionDraft = () => {
      const snapshot = readSessionDraft()

      if (!snapshot?.blocks) {
        return false
      }

      renderBlocks(snapshot.blocks)
      updatePageStatus(config.labels.sessionRestored, "dirty")
      return true
    }

    const currentGridMetrics = () => {
      const styles = getComputedStyle(board)
      const cellSize = Number.parseFloat(styles.getPropertyValue("--help-grid-cell-size") || "240") || 240
      const rowSize = Number.parseFloat(styles.getPropertyValue("--help-grid-row-size") || `${cellSize}`) || cellSize

      return {
        columnStride: cellSize + gap,
        rowStride: rowSize + gap
      }
    }

    const pointerToCell = (event) => {
      const boardRect = board.getBoundingClientRect()
      const { columnStride, rowStride } = currentGridMetrics()
      const offsetX = clamp(event.clientX - boardRect.left, 0, Math.max(boardRect.width - 1, 0))
      const offsetY = Math.max(event.clientY - boardRect.top, 0)

      return {
        column: clamp(Math.floor(offsetX / columnStride) + 1, 1, columns),
        row: Math.max(Math.floor(offsetY / rowStride) + 1, 1)
      }
    }

    const pointerDeltaToGridDelta = (event, interaction) => {
      const { columnStride, rowStride } = currentGridMetrics()

      const snapDelta = (distance, stride) => {
        const ratio = distance / stride

        if (ratio >= 0) {
          return Math.floor(ratio + 0.5)
        }

        return Math.ceil(ratio - 0.5)
      }

      return {
        columns: snapDelta(event.clientX - interaction.originClientX, columnStride),
        rows: snapDelta(event.clientY - interaction.originClientY, rowStride)
      }
    }

    const proposedMoveLayout = (interaction) => ({
      columnStart: clamp(interaction.initialLayout.columnStart + (interaction.deltaColumns || 0), 1, columns - interaction.initialLayout.columnSpan + 1),
      columnSpan: interaction.initialLayout.columnSpan,
      rowStart: Math.max(interaction.initialLayout.rowStart + (interaction.deltaRows || 0), 1),
      rowSpan: interaction.initialLayout.rowSpan
    })

    const layoutContainsCell = (layout, cell) => (
      cell.column >= layout.columnStart &&
      cell.column <= layout.columnStart + layout.columnSpan - 1 &&
      cell.row >= layout.rowStart &&
      cell.row <= layout.rowStart + layout.rowSpan - 1
    )

    const findSwapTarget = (sourceForm, cell) => {
      if (!cell) {
        return null
      }

      return Array.from(board.querySelectorAll("[data-help-grid-item]"))
        .find((candidate) => candidate !== sourceForm && layoutContainsCell(readLayout(candidate), cell))
    }

    const layoutsOverlap = (firstLayout, secondLayout) => (
      firstLayout.rowStart <= secondLayout.rowStart + secondLayout.rowSpan - 1 &&
      secondLayout.rowStart <= firstLayout.rowStart + firstLayout.rowSpan - 1 &&
      firstLayout.columnStart <= secondLayout.columnStart + secondLayout.columnSpan - 1 &&
      secondLayout.columnStart <= firstLayout.columnStart + firstLayout.columnSpan - 1
    )

    const hasLayoutConflict = (sourceForm, proposedLayout = readLayout(sourceForm)) => Array.from(board.querySelectorAll("[data-help-grid-item]"))
      .some((candidate) => candidate !== sourceForm && layoutsOverlap(proposedLayout, readLayout(candidate)))

    Array.from(board.querySelectorAll("[data-help-grid-item]"))
      .forEach((form) => {
        initializeForm(form)
      })

    updateBoardRowCount()

    if (!restoreSessionDraft()) {
      updatePageStatus(config.initialPageStatus, config.initialPageState)
    }

    let activeInteraction = null

    const finishInteraction = () => {
      if (!activeInteraction) {
        return
      }

      const { form, mode, initialLayout, lastCell } = activeInteraction

      form.style.transform = ""

      if (mode === "move") {
        const swapTarget = findSwapTarget(form, lastCell)

        if (swapTarget) {
          const targetLayout = readLayout(swapTarget)
          applyLayout(form, targetLayout)
          applyLayout(swapTarget, initialLayout)
          updateBoardRowCount()
          form.classList.remove("is-dragging", "is-resizing")
          swapTarget.classList.remove("is-dragging", "is-resizing")
          activeInteraction = null
          markLocalDraftDirty(config.labels.localDirty)
          return
        }

        applyLayout(form, proposedMoveLayout(activeInteraction))
      }

      if (hasLayoutConflict(form)) {
        applyLayout(form, initialLayout)
        updateBoardRowCount()
      }

      form.classList.remove("is-dragging", "is-resizing")
      activeInteraction = null
      markLocalDraftDirty(config.labels.localDirty)
    }

    board.addEventListener("mousedown", (event) => {
      if (window.innerWidth <= 991) {
        return
      }

      if (event.button !== 0) {
        return
      }

      const form = event.target.closest("[data-help-grid-item]")

      if (!form) {
        return
      }

      const resizeHandle = event.target.closest("[data-help-resize-edge]")
      const moveHandle = event.target.closest("[data-help-move-handle]")

      if (!resizeHandle && !moveHandle) {
        return
      }

      event.preventDefault()

      const cell = pointerToCell(event)
      const edges = {
        top: resizeHandle?.dataset.helpResizeEdge?.includes("top") || false,
        right: resizeHandle?.dataset.helpResizeEdge?.includes("right") || false,
        bottom: resizeHandle?.dataset.helpResizeEdge?.includes("bottom") || false,
        left: resizeHandle?.dataset.helpResizeEdge?.includes("left") || false
      }

      activeInteraction = {
        form,
        mode: resizeHandle ? "resize" : "move",
        edges,
        originClientX: event.clientX,
        originClientY: event.clientY,
        initialLayout: readLayout(form),
        deltaColumns: 0,
        deltaRows: 0,
        lastCell: cell
      }

      form.classList.add(resizeHandle ? "is-resizing" : "is-dragging")
    })

    window.addEventListener("mousemove", (event) => {
      if (!activeInteraction) {
        return
      }

      const { form, mode, edges, initialLayout } = activeInteraction
      const cell = pointerToCell(event)
      const { columns: deltaColumns, rows: deltaRows } = pointerDeltaToGridDelta(event, activeInteraction)

      activeInteraction.lastCell = cell

      if (mode === "move") {
        activeInteraction.deltaColumns = deltaColumns
        activeInteraction.deltaRows = deltaRows
        form.style.transform = `translate(${event.clientX - activeInteraction.originClientX}px, ${event.clientY - activeInteraction.originClientY}px)`
      }

      if (mode === "resize") {
        let columnStart = initialLayout.columnStart
        let columnSpan = initialLayout.columnSpan
        let rowStart = initialLayout.rowStart
        let rowSpan = initialLayout.rowSpan

        if (edges.left) {
          columnStart = clamp(initialLayout.columnStart + deltaColumns, 1, initialLayout.columnStart + initialLayout.columnSpan - 1)
          columnSpan = initialLayout.columnSpan + (initialLayout.columnStart - columnStart)
        }

        if (edges.right) {
          columnSpan = clamp(initialLayout.columnSpan + deltaColumns, 1, columns - columnStart + 1)
        }

        if (edges.top) {
          rowStart = Math.max(initialLayout.rowStart + deltaRows, 1)
          rowSpan = initialLayout.rowSpan + (initialLayout.rowStart - rowStart)
        }

        if (edges.bottom) {
          rowSpan = Math.max(initialLayout.rowSpan + deltaRows, 1)
        }

        readField(form, "column_start").value = columnStart
        readField(form, "column_span").value = columnSpan
        readField(form, "row_start").value = rowStart
        readField(form, "row_span").value = rowSpan
      }

      if (mode === "resize") {
        syncFormLayout(form)
        updateBoardRowCount()
      }
    })

    window.addEventListener("mouseup", finishInteraction)

    board.addEventListener("input", (event) => {
      const editor = event.target.closest('[data-help-card-editor]')
      if (!editor) {
        return
      }

      const form = editor.closest("[data-help-grid-item]")
      if (!form) {
        return
      }

      syncBodyFromEditor(form)
      syncPreview(form)
      markLocalDraftDirty(config.labels.localDirty)
    })

    board.addEventListener("mouseup", (event) => {
      const editor = event.target.closest('[data-help-card-editor]')
      if (editor) {
        setActiveFormattingTarget(editor)
      }
    })

    board.addEventListener("keyup", (event) => {
      const editor = event.target.closest('[data-help-card-editor]')
      if (editor) {
        setActiveFormattingTarget(editor)
      }
    })

    board.addEventListener("contextmenu", (event) => {
      const editor = event.target.closest('[data-help-card-editor]')
      if (!editor) {
        return
      }

      event.preventDefault()
      setActiveFormattingTarget(editor)
      positionFormattingMenu(event.clientX, event.clientY)
    })

    board.addEventListener("click", (event) => {
      const previewToggle = event.target.closest("[data-help-preview-toggle]")
      if (previewToggle) {
        event.preventDefault()

        const form = previewToggle.closest("[data-help-grid-item]")
        const nextState = form?.dataset.previewMode !== "true"
        if (form) {
          setPreviewMode(form, nextState)
        }

        closeFormattingMenu()
        return
      }

      const deleteButton = event.target.closest("[data-help-delete-card]")
      if (!deleteButton) {
        return
      }

      event.preventDefault()

      if (!window.confirm(config.labels.deleteConfirm)) {
        return
      }

      deleteButton.closest("[data-help-grid-item]")?.remove()
      closeFormattingMenu()
      ensureEmptyState()
      markLocalDraftDirty(config.labels.cardDeleted)
    })

    addCardButton?.addEventListener("click", () => {
      board.querySelector(".help-grid-empty-state")?.remove()

      const newBlock = buildBlockElement({
        id: createLocalId(),
        body: config.defaults.body,
        style_variant: "card",
        column_start: 1,
        column_span: 1,
        row_start: nextAvailableRow(),
        row_span: 1
      })

      board.append(newBlock)
      markLocalDraftDirty(config.labels.cardAdded)
    })

    const withToolbarRequest = async (callback) => {
      const buttons = [saveDraftButton, publishDraftButton, addCardButton].filter(Boolean)
      buttons.forEach((element) => { element.disabled = true })

      try {
        await callback()
      } finally {
        buttons.forEach((element) => { element.disabled = false })
        if (publishDraftButton && config.draftAvailable !== true) {
          publishDraftButton.disabled = true
        }
      }
    }

    saveDraftButton?.addEventListener("click", async () => {
      await withToolbarRequest(async () => {
        updatePageStatus(config.labels.draftSaving, "saving")

        const response = await fetch(config.paths.saveDraft, {
          method: "PATCH",
          headers: {
            Accept: "application/json",
            "Content-Type": "application/json",
            ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {})
          },
          credentials: "same-origin",
          body: JSON.stringify({ blocks: writeSessionDraft().blocks })
        })

        const payload = await response.json().catch(() => ({ errors: [config.labels.saveError] }))

        if (!response.ok) {
          updatePageStatus((payload.errors || [config.labels.saveError]).join(" "), "error")
          return
        }

        config.draftAvailable = true
        publishDraftButton && (publishDraftButton.disabled = false)
        updatePageStatus(formatLabel(config.labels.draftSavedAt, { time: formatTimestamp(payload.saved_at) || "--" }), "success")
      })
    })

    publishDraftButton?.addEventListener("click", async () => {
      await withToolbarRequest(async () => {
        updatePageStatus(config.labels.publishing, "saving")

        const response = await fetch(config.paths.publishDraft, {
          method: "POST",
          headers: {
            Accept: "application/json",
            ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {})
          },
          credentials: "same-origin"
        })

        const payload = await response.json().catch(() => ({ errors: [config.labels.publishError] }))

        if (!response.ok) {
          updatePageStatus((payload.errors || [config.labels.publishError]).join(" "), "error")
          return
        }

        config.draftAvailable = true
        updatePageStatus(formatLabel(config.labels.publishedAt, { time: formatTimestamp(payload.published_at) || "--" }), "success")
      })
    })

    if (publishDraftButton && config.draftAvailable !== true) {
      publishDraftButton.disabled = true
    }
  })
}

document.addEventListener("turbo:load", attachHelpGridEditors)