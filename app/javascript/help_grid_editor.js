import DOMPurify from "dompurify"

const HELP_RICH_TEXT_ALLOWED_TAGS = ["p", "br", "div", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "li", "strong", "b", "em", "i", "a", "code", "pre", "blockquote", "hr", "table", "thead", "tbody", "tr", "th", "td", "span", "u", "mark"]
const HELP_RICH_TEXT_ALLOWED_ATTRIBUTES = ["href", "title", "rel", "target", "class"]
const HELP_RICH_TEXT_ALLOWED_CLASSES = new Set([
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
  "help-md-highlight--green",
  "help-md-highlight--yellow",
  "help-md-highlight--red"
])

const helpDeleteIcon = `
  <svg class="help-grid-block__icon-svg" viewBox="0 0 10 10" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true" focusable="false">
    <path d="M1 1L9 9" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"/>
    <path d="M9 1L1 9" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"/>
  </svg>
`

const sanitizeHelpRichText = (content) => {
  const sanitizedHtml = DOMPurify.sanitize(content || "", {
    ALLOWED_TAGS: HELP_RICH_TEXT_ALLOWED_TAGS,
    ALLOWED_ATTR: HELP_RICH_TEXT_ALLOWED_ATTRIBUTES
  })
  const wrapper = document.createElement("div")

  wrapper.innerHTML = sanitizedHtml
  wrapper.querySelectorAll("b").forEach((element) => {
    const replacement = document.createElement("strong")
    replacement.innerHTML = element.innerHTML
    element.replaceWith(replacement)
  })
  wrapper.querySelectorAll("i").forEach((element) => {
    const replacement = document.createElement("em")
    replacement.innerHTML = element.innerHTML
    element.replaceWith(replacement)
  })
  wrapper.querySelectorAll("[class]").forEach((element) => {
    const allowedClasses = Array.from(element.classList).filter((className) => HELP_RICH_TEXT_ALLOWED_CLASSES.has(className))

    if (allowedClasses.length) {
      element.setAttribute("class", allowedClasses.join(" "))
    } else {
      element.removeAttribute("class")
    }
  })
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
    const readDeleteButton = (form) => form.querySelector("[data-help-delete-card]")
    const helpDeleteModal = document.getElementById("help-delete-confirmation-modal")
    const helpDeleteConfirmButton = helpDeleteModal?.querySelector("[data-help-delete-confirm]")
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

    let pendingDeleteForm = null

    const openDeleteModal = (form) => {
      pendingDeleteForm = form
      helpDeleteModal?.removeAttribute("hidden")
    }

    const closeDeleteModal = () => {
      pendingDeleteForm = null
      helpDeleteModal?.setAttribute("hidden", "hidden")
    }

    helpDeleteConfirmButton?.addEventListener("click", () => {
      pendingDeleteForm?.remove()
      closeFormattingMenu()
      ensureEmptyState()
      markLocalDraftDirty(config.labels.cardDeleted)
      closeDeleteModal()
    })

    helpDeleteModal?.addEventListener("click", (event) => {
      if (event.target === helpDeleteModal) {
        closeDeleteModal()
        return
      }

      const closeButton = event.target.closest('[data-delete-modal-close="help-delete-confirmation-modal"]')
      if (closeButton) {
        closeDeleteModal()
      }
    })

    const syncEditorFromBody = (form) => {
      const editor = readEditorField(form)
      const bodyField = readBodyField(form)
      if (!editor || !bodyField) {
        return
      }

      const initialHtml = editor.innerHTML.trim()
      editor.innerHTML = sanitizeHelpRichText(initialHtml || bodyField.value || "")
      syncBodyFromEditor(form, { replaceEditor: true })
    }

    const syncBodyFromEditor = (form, options = {}) => {
      const editor = readEditorField(form)
      const bodyField = readBodyField(form)
      if (!editor || !bodyField) {
        return
      }

      const sanitizedHtml = sanitizeHelpRichText(editor.innerHTML)
      bodyField.value = sanitizedHtml

      if (options.replaceEditor === true) {
        editor.innerHTML = sanitizedHtml
      }
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
    }

    const buildSelectOptions = (items = []) => items.map((item) => `<option value="${item.value}">${item.label}</option>`).join("")
    const buildFormattingField = (label, items = []) => {
      if (!items.length) {
        return ""
      }

      return `
        <label class="help-grid-format-menu__field">
          <span>${label}</span>
          <select data-help-format-command>
            <option value="">${formatting.chooseOption}</option>
            ${buildSelectOptions(items)}
          </select>
        </label>
      `
    }

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
        ${buildFormattingField(formatting.textLabel, formatting.textStyles)}
        ${buildFormattingField(formatting.markerLabel, formatting.markers)}
        ${buildFormattingField(formatting.sizeLabel, formatting.sizes)}
        ${buildFormattingField(formatting.blockLabel, formatting.blocks)}
      `

      document.body.append(menu)
      return menu
    }

    const formattingMenu = buildFormattingMenu()
    let activeFormattingTarget = null
    const editorHistories = new WeakMap()
    const editorHistoryLimit = 80

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

    const fallbackEditorRange = (editor) => {
      const range = document.createRange()

      range.selectNodeContents(editor)
      range.collapse(false)

      return range
    }

    const editorOwnsNode = (editor, node) => {
      if (!node) {
        return false
      }

      const element = node.nodeType === Node.TEXT_NODE ? node.parentNode : node
      return editor === element || editor.contains(element)
    }

    const captureEditorSelection = (editor) => {
      const selection = window.getSelection()
      if (!selection || selection.rangeCount === 0) {
        return null
      }

      const range = selection.getRangeAt(0)
      if (!editorOwnsNode(editor, range.startContainer) || !editorOwnsNode(editor, range.endContainer)) {
        return null
      }

      const startRange = document.createRange()
      startRange.selectNodeContents(editor)
      startRange.setEnd(range.startContainer, range.startOffset)

      const endRange = document.createRange()
      endRange.selectNodeContents(editor)
      endRange.setEnd(range.endContainer, range.endOffset)

      return {
        start: startRange.toString().length,
        end: endRange.toString().length
      }
    }

    const resolveEditorTextPosition = (editor, offset) => {
      const walker = document.createTreeWalker(editor, NodeFilter.SHOW_TEXT)
      let remainingOffset = Math.max(offset, 0)
      let textNode = walker.nextNode()

      while (textNode) {
        const textLength = textNode.textContent.length
        if (remainingOffset <= textLength) {
          return { node: textNode, offset: remainingOffset }
        }

        remainingOffset -= textLength
        textNode = walker.nextNode()
      }

      return { node: editor, offset: editor.childNodes.length }
    }

    const restoreEditorSelection = (editor, snapshot) => {
      const selection = window.getSelection()
      if (!selection) {
        return
      }

      const range = document.createRange()

      if (snapshot?.selection) {
        const start = resolveEditorTextPosition(editor, snapshot.selection.start)
        const end = resolveEditorTextPosition(editor, snapshot.selection.end)
        range.setStart(start.node, start.offset)
        range.setEnd(end.node, end.offset)
      } else {
        range.selectNodeContents(editor)
        range.collapse(false)
      }

      editor.focus()
      selection.removeAllRanges()
      selection.addRange(range)
    }

    const captureEditorSnapshot = (editor) => ({
      html: sanitizeHelpRichText(editor.innerHTML),
      selection: captureEditorSelection(editor)
    })

    const ensureEditorHistory = (editor) => {
      let history = editorHistories.get(editor)
      if (!history) {
        history = {
          entries: [captureEditorSnapshot(editor)],
          index: 0,
          applying: false
        }
        editorHistories.set(editor, history)
      }

      return history
    }

    const recordEditorHistory = (editor) => {
      const history = ensureEditorHistory(editor)
      if (history.applying) {
        return
      }

      const snapshot = captureEditorSnapshot(editor)
      const current = history.entries[history.index]
      if (current?.html === snapshot.html) {
        history.entries[history.index] = snapshot
        return
      }

      if (history.index < history.entries.length - 1) {
        history.entries = history.entries.slice(0, history.index + 1)
      }

      history.entries.push(snapshot)
      if (history.entries.length > editorHistoryLimit) {
        history.entries.shift()
      }
      history.index = history.entries.length - 1
    }

    const applyEditorHistory = (editor, direction) => {
      const history = ensureEditorHistory(editor)
      const nextIndex = history.index + direction
      if (nextIndex < 0 || nextIndex >= history.entries.length) {
        return false
      }

      history.applying = true

      try {
        const snapshot = history.entries[nextIndex]
        editor.innerHTML = snapshot.html
        history.index = nextIndex

        const form = editor.closest("[data-help-grid-item]")
        if (form) {
          syncBodyFromEditor(form)
          markLocalDraftDirty(config.labels.localDirty)
        }

        restoreEditorSelection(editor, snapshot)
        setActiveFormattingTarget(editor)
      } finally {
        history.applying = false
      }

      return true
    }

    const setActiveFormattingTarget = (editor) => {
      ensureEditorHistory(editor)
      activeFormattingTarget = {
        editor,
        range: captureEditorRange(editor) || fallbackEditorRange(editor)
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
      if (!activeFormattingTarget?.editor) {
        return
      }

      const { editor, range } = activeFormattingTarget
      const selection = window.getSelection()

      editor.focus()
      if (selection && range) {
        selection.removeAllRanges()
        selection.addRange(range.cloneRange())
      }

      callback(editor)
    }

    const insertCodeBlock = () => {
      const selection = window.getSelection()
      if (!selection || selection.rangeCount === 0) {
        return
      }

      const range = selection.getRangeAt(0)
      const pre = document.createElement("pre")
      const code = document.createElement("code")
      const selectedText = range.collapsed ? "" : range.toString()

      if (selectedText) {
        code.textContent = selectedText
      } else {
        code.append(document.createElement("br"))
      }

      pre.append(code)
      range.deleteContents()
      range.insertNode(pre)

      const updatedRange = document.createRange()
      updatedRange.selectNodeContents(code)
      updatedRange.collapse(!selectedText)

      selection.removeAllRanges()
      selection.addRange(updatedRange)
    }

    const wrapSelection = (tagName, classNames = []) => {
      const selection = window.getSelection()
      if (!selection || selection.rangeCount === 0) {
        return false
      }

      const range = selection.getRangeAt(0)
      if (range.collapsed) {
        return false
      }

      const wrapper = document.createElement(tagName)
      if (classNames.length) {
        wrapper.className = classNames.join(" ")
      }

      wrapper.append(range.extractContents())
      range.insertNode(wrapper)

      const updatedRange = document.createRange()
      updatedRange.selectNodeContents(wrapper)
      selection.removeAllRanges()
      selection.addRange(updatedRange)

      return true
    }

    const markFormattingApplied = (editor) => {
      const form = editor.closest("[data-help-grid-item]")
      if (form) {
        syncBodyFromEditor(form)
        markLocalDraftDirty(config.labels.localDirty)
        recordEditorHistory(editor)
      }

      setActiveFormattingTarget(editor)
    }

    const applyFormattingCommand = (command) => {
      withStoredSelection((editor) => {
        let applied = false

        if (command === "bold") {
          document.execCommand("bold")
          applied = true
        }

        if (command === "italic") {
          document.execCommand("italic")
          applied = true
        }

        if (command === "underline") {
          document.execCommand("underline")
          applied = true
        }

        if (command === "highlight_green") {
          applied = wrapSelection("mark", ["help-md-highlight", "help-md-highlight--green"])
        }

        if (command === "highlight_yellow") {
          applied = wrapSelection("mark", ["help-md-highlight", "help-md-highlight--yellow"])
        }

        if (command === "highlight_red") {
          applied = wrapSelection("mark", ["help-md-highlight", "help-md-highlight--red"])
        }

        if (command === "size_sm") {
          applied = wrapSelection("span", ["help-md-size-sm"])
        }

        if (command === "size_md") {
          applied = wrapSelection("span", ["help-md-size-md"])
        }

        if (command === "size_lg") {
          applied = wrapSelection("span", ["help-md-size-lg"])
        }

        if (command === "unordered_list") {
          document.execCommand("insertUnorderedList")
          applied = true
        }

        if (command === "ordered_list") {
          document.execCommand("insertOrderedList")
          applied = true
        }

        if (command === "code_block") {
          insertCodeBlock()
          applied = true
        }

        if (applied) {
          markFormattingApplied(editor)
        }
      })
    }

    formattingMenu.addEventListener("change", (event) => {
      const select = event.target.closest("[data-help-format-command]")
      if (!select || !select.value) {
        return
      }

      applyFormattingCommand(select.value)
      select.value = ""
      closeFormattingMenu()
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
    const closeEditorPath = config.paths.closeEditor
    const closeEditorAfterRequest = () => {
      if (!closeEditorPath) {
        return
      }

      if (window.Turbo?.visit) {
        window.Turbo.visit(closeEditorPath)
      } else {
        window.location.assign(closeEditorPath)
      }
    }
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
          <div class="help-grid-block__editor" data-help-card-editor contenteditable="true" role="textbox" aria-multiline="true" dir="ltr" spellcheck="true" data-placeholder="${config.labels.bodyPlaceholder}"></div>
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

    board.addEventListener("focusin", (event) => {
      const editor = event.target.closest('[data-help-card-editor]')
      if (editor) {
        setActiveFormattingTarget(editor)
      }
    })

    board.addEventListener("beforeinput", (event) => {
      const editor = event.target.closest('[data-help-card-editor]')
      if (!editor) {
        return
      }

      if (event.inputType === "historyUndo" && applyEditorHistory(editor, -1)) {
        event.preventDefault()
      }

      if (event.inputType === "historyRedo" && applyEditorHistory(editor, 1)) {
        event.preventDefault()
      }
    })

    board.addEventListener("keydown", (event) => {
      const editor = event.target.closest('[data-help-card-editor]')
      if (!editor || event.altKey || (!event.ctrlKey && !event.metaKey)) {
        return
      }

      const key = event.key.toLowerCase()
      const undoRequested = key === "z" && !event.shiftKey
      const redoRequested = (key === "z" && event.shiftKey) || key === "y"

      if (!undoRequested && !redoRequested) {
        return
      }

      if (applyEditorHistory(editor, undoRequested ? -1 : 1)) {
        event.preventDefault()
        event.stopPropagation()
      }
    })

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
      markLocalDraftDirty(config.labels.localDirty)
      recordEditorHistory(editor)
      setActiveFormattingTarget(editor)
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
      const deleteButton = event.target.closest("[data-help-delete-card]")
      if (!deleteButton) {
        return
      }

      event.preventDefault()
      openDeleteModal(deleteButton.closest("[data-help-grid-item]"))
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

    const saveCurrentDraft = async () => {
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
        return null
      }

      config.draftAvailable = true
      publishDraftButton && (publishDraftButton.disabled = false)

      return payload
    }

    saveDraftButton?.addEventListener("click", async () => {
      await withToolbarRequest(async () => {
        updatePageStatus(config.labels.draftSaving, "saving")

        const payload = await saveCurrentDraft()
        if (!payload) {
          return
        }

        updatePageStatus(formatLabel(config.labels.draftSavedAt, { time: formatTimestamp(payload.saved_at) || "--" }), "success")
        closeEditorAfterRequest()
      })
    })

    publishDraftButton?.addEventListener("click", async () => {
      await withToolbarRequest(async () => {
        updatePageStatus(config.labels.draftSaving, "saving")

        const draftPayload = await saveCurrentDraft()
        if (!draftPayload) {
          return
        }

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
        window.sessionStorage.removeItem(storageKey)
        closeEditorAfterRequest()
      })
    })

    if (publishDraftButton && config.draftAvailable !== true) {
      publishDraftButton.disabled = true
    }
  })
}

document.addEventListener("turbo:load", attachHelpGridEditors)