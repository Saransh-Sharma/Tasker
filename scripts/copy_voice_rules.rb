# frozen_string_literal: true

# Word lists for DESIGN.md "Voice and copy", shared by the launch-contract
# ratchet (check_launch_contracts.rb) and the copy inventory
# (copy_inventory.rb). Change the lists here and in DESIGN.md together.
module CopyVoiceRules
  VOICE_SMELL = [
    'gentle', 'gently', 'calm', 'calmer', 'quiet', 'quietly', 'honest', 'softly', 'breathe',
    'room to', 'still counts', "when you're ready", 'when you’re ready', 'whenever you',
    'no pressure', 'nothing to force', 'intentional', 'intentionally', 'meaningful',
    'deliberately', 'one small', 'tiny', "let's", 'let’s', 'journey', 'seamless',
    'seamlessly', 'effortless', 'effortlessly', 'empower', "here's", 'here’s',
    "you've got this", 'you’ve got this'
  ].freeze

  DISCLAIMER = [
    'not a verdict', 'not a score', 'never a grade', 'without judg', 'without blame',
    'lifeboard never', 'lifeboard does not', "lifeboard doesn't", 'lifeboard doesn’t',
    'non-clinical', 'not a diagnosis'
  ].freeze

  UI_JARGON = [
    'canonical', 'evidence', 'bounded', 'deterministic', 'denominator', 'sidecar', 'sidecars',
    'projection', 'tombstone', 'idempotent', 'grounded', 'non-authoritative', 'pseudonymous',
    'billable', 'provider', 'occurrence', 'occurrences', 'ledger', 'MLX', 'Cloudflare', 'Luna',
    'chief of staff', 'behavior loop', 'behavior loops'
  ].freeze

  # Files that hold instructions for a language model rather than text a
  # person reads. Their wording is governed by the Eva prompt contracts.
  PROMPT_FILES = %r{
    Features/Eva/Context/(EvaContextEnvelope|EvaContextSectionFactory|EvaEnvelopeAllocator|EvaPlanningProjector)
    | Features/Eva/Cloud/(EvaPromptAssembly|EvaCloudContracts)\.swift
    | Features/Eva/Models/(PromptMiddleware|AISuggestionPromptPayloads|LLMContextProjectionService)\.swift
    | Features/Eva/Views/Chat/(EvaChatPromptSnapshotFactory|EvaChatRetryPromptFactory)\.swift
    | EvaTurnContextAssembler\.swift
    | Features/Eva/Models/Data\.swift
    | Features/Journal/Domain/JournalEvidenceService\.swift
    | Features/Onboarding/LifeMap/LifeMapEvaHandoff\.swift
  }x.freeze

  # Reviewed exceptions: a file may use a rule's words for the stated reason
  # and nothing else. Add a row only with the reason; the voice rules are hard
  # everywhere else (check_launch_contracts.rb).
  ALLOWED = [
    [%r{Persistence/}, 'ui-jargon', 'Core Data entity names, keys, and developer-facing repository errors'],
    [%r{Features/Sync/Domain/}, 'ui-jargon', 'developer-facing configuration errors'],
    [%r{Features/Journal/Domain/SemanticMemoryIndexActor\.swift}, 'ui-jargon', 'semantic index diagnostics'],
    [%r{Features/Track/Domain/TrackFoundationModels\.swift}, 'ui-jargon', 'labels in the block sent to Eva'],
    [%r{Features/Track/Data/TrackFoundationPersistence\.swift}, 'ui-jargon', 'Core Data entity name'],
    [%r{Features/Plan/Domain/MaintainOccurrencesUseCase\.swift}, 'ui-jargon', 'Core Data entity name'],
    [%r{Foundation/Navigation/RootTransition\.swift}, 'ui-jargon', 'Core Data entity name'],
    [%r{Utils/LoggingService\.swift}, 'ui-jargon', 'log field name'],
    [%r{Features/Eva/Views/Settings/CreditsView\.swift}, 'ui-jargon', 'the library is called MLX Swift'],
    [%r{Features/Eva/Cloud/EvaCloudRequest\.swift}, 'eva-caps', 'HTTP header names on the wire'],
    [%r{Features/Eva/UI/SunriseEvaSheets\.swift}, 'voice-smell', 'keywords matched against task titles, not shown'],
    [%r{Features/Onboarding/Models/StarterWorkspaceCatalog\.swift}, 'voice-smell', 'habit-ranking keyword, not shown']
  ].freeze

  def self.allowed?(path, rule)
    ALLOWED.any? { |pattern, allowed_rule, _| allowed_rule == rule && path =~ pattern }
  end

  # Test seed data is never read by a person outside a test run.
  NON_UI_FILES = %r{/TestingSupport/}.freeze

  # Feature and mood names that happen to share a word with the lists:
  # the "Quiet hours" setting, and "Calm" as a mood or motion level.
  NAMED_FEATURES = /quiet\s+hours/i.freeze
  NAMED_LITERALS = %w[Calm calm].freeze

  # Lines whose literals never reach a person.
  NON_UI_LINE = /\b(Logger|logger|os_log|NSLog|print|debugPrint|fatalError|assert|assertionFailure|precondition|preconditionFailure|forKey|UserDefaults|accessibilityIdentifier|identifier:|entityName|forEntityName|NSSortDescriptor|NSPredicate|forHTTPHeaderField|field:|value\(forKey)\b|#Preview\(/.freeze

  STRING_LITERAL = /"((?:[^"\\\n]|\\.)*)"/.freeze

  def self.phrase_pattern(list)
    alternatives = list.map do |phrase|
      escaped = Regexp.escape(phrase).gsub('\\ ', '\\s+')
      "(?<![\\p{L}\\p{N}])#{escaped}(?![\\p{L}\\p{N}])"
    end
    Regexp.new(alternatives.join('|'), Regexp::IGNORECASE)
  end

  VOICE_SMELL_PATTERN = phrase_pattern(VOICE_SMELL)
  DISCLAIMER_PATTERN = phrase_pattern(DISCLAIMER)
  UI_JARGON_PATTERN = phrase_pattern(UI_JARGON)
  ASCII_ELLIPSIS_PATTERN = /\.\.\./.freeze

  # A key, identifier, symbol name, or URL rather than prose.
  def self.machine_string?(text)
    return true if text.strip.empty?
    return false if text =~ /\s/

    text.include?('.') || text.include?('_') || text.include?('/') || text =~ /\A[a-z]+[A-Z]/
  end

  # A call whose string arguments are for developers: `logWarning(`,
  # `logger.error(`, `print(` …, often spread over several lines.
  LOG_CALL = /\b(?:log|log[A-Z]\w*|\w*[Ll]ogger\.\w+|Logger\(\)\.\w+|os_log|NSLog|print|debugPrint|fatalError|assertionFailure|preconditionFailure)\s*\(/.freeze

  # [line, index] pairs outside log calls, so a multi-line
  # `logWarning(event:, message: "…")` is never read as copy.
  def self.ui_lines(lines)
    depth = 0
    lines.each_with_index.each_with_object([]) do |(line, index), kept|
      if depth.positive?
        depth += line.count('(') - line.count(')')
        next
      end
      if (match = LOG_CALL.match(line))
        tail = line[match.begin(0)..]
        opened = tail.count('(') - tail.count(')')
        depth = opened if opened.positive?
        next
      end
      kept << [line, index]
    end
  end

  # The literals on a line that could be read by a person.
  def self.ui_literals(line)
    return [] if line.strip.start_with?('//', '*', '///')
    return [] if line =~ NON_UI_LINE

    line.scan(STRING_LITERAL).flatten
        .reject { |text| machine_string?(text) || NAMED_LITERALS.include?(text) }
        .map { |text| without_interpolations(text).gsub(NAMED_FEATURES, '') }
  end

  # `\(value.formatted(…0...1…))` is code inside the literal, not copy.
  def self.without_interpolations(text)
    output = +''
    depth = 0
    index = 0
    while index < text.length
      if depth.zero? && text[index] == '\\' && text[index + 1] == '('
        depth = 1
        index += 2
        next
      end
      if depth.positive?
        depth += 1 if text[index] == '('
        depth -= 1 if text[index] == ')'
        output << ' ' if depth.zero?
      else
        output << text[index]
      end
      index += 1
    end
    output
  end
end
