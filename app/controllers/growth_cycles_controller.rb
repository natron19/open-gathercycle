class GrowthCyclesController < ApplicationController
  rate_limit to: 5, within: 1.minute, only: [:create],
             with: -> { redirect_to new_growth_cycle_path, alert: "Please wait a moment before generating another plan." }

  def index
    @cycles = current_user.growth_cycles.order(created_at: :desc)
  end

  def new
    @cycle = GrowthCycle.new
  end

  def create
    @cycle = current_user.growth_cycles.build(growth_cycle_params)

    raw = GeminiService.generate(
      template:  "gathercycle_plan_v1",
      variables: {
        organization_name:    @cycle.organization_name,
        time_period:          @cycle.time_period,
        goal_description:     @cycle.goal_description,
        audience_description: @cycle.audience_description
      }
    )

    @cycle.gemini_raw = raw
    json_str = raw[/\{.+\}/m]
    raise JSON::ParserError, "No JSON object found in Gemini response" unless json_str
    json_str = json_str.gsub(/,(\s*[}\]])/, '\1')                           # trailing commas
    json_str = json_str.gsub(/([}\]])(\s*)([{\["])/) { "#{$1},#{$2}#{$3}" } # missing commas
    parsed = JSON.parse(json_str)

    ActiveRecord::Base.transaction do
      @cycle.save!
      parsed["phases"].each do |phase_data|
        phase_data["tasks"].each_with_index do |task_data, idx|
          @cycle.cycle_tasks.create!(
            phase:             phase_data["phase"],
            title:             task_data["title"],
            owner_type:        task_data["owner_type"],
            effort_estimate:   task_data["effort_estimate"],
            success_indicator: task_data["success_indicator"],
            position:          idx
          )
        end
      end
    end

    redirect_to growth_cycle_path(@cycle), notice: "Your cycle plan is ready."

  rescue GeminiService::BudgetExceededError
    @error_type = :budget_exceeded
    render :new, status: :unprocessable_entity
  rescue GeminiService::GatekeeperError
    @error_type = :gatekeeper_blocked
    render :new, status: :unprocessable_entity
  rescue GeminiService::TimeoutError
    @error_type = :timeout
    render :new, status: :unprocessable_entity
  rescue GeminiService::GeminiError
    @error_type = :error
    render :new, status: :unprocessable_entity
  rescue JSON::ParserError => e
    Rails.logger.warn("[GatherCycle] JSON parse failed: #{e.message} | tokens: #{raw.to_s.length} chars")
    flash.now[:alert] = "Gemini returned an unexpected format. Please try again. If the problem persists, check the admin LLM request log."
    render :new, status: :unprocessable_entity
  end

  def show
    @cycle = current_user.growth_cycles.find(params[:id])
    @phases = @cycle.cycle_tasks.order(:position).group_by(&:phase)
  end

  def download
    @cycle = current_user.growth_cycles.find(params[:id])
    phases = @cycle.cycle_tasks.order(:position).group_by(&:phase)
    filename = "#{@cycle.name.parameterize}-#{@cycle.time_period.parameterize}.md"
    send_data markdown_for(@cycle, phases), filename: filename, type: "text/plain", disposition: "attachment"
  end

  def destroy
    cycle = current_user.growth_cycles.find(params[:id])
    cycle.destroy!
    redirect_to growth_cycles_path, notice: "Cycle deleted."
  end

  private

  PHASE_ORDER  = %w[awareness engagement consolidation].freeze
  PHASE_LABELS = {
    "awareness"     => "Phase 1: Awareness",
    "engagement"    => "Phase 2: Engagement",
    "consolidation" => "Phase 3: Consolidation"
  }.freeze

  def markdown_for(cycle, phases)
    lines = []
    lines << "# #{cycle.name}"
    lines << ""
    lines << "| | |"
    lines << "|---|---|"
    lines << "| **Organization** | #{cycle.organization_name} |"
    lines << "| **Period** | #{cycle.time_period} |"
    lines << "| **Goal** | #{cycle.goal_description} |"
    lines << "| **Audience** | #{cycle.audience_description} |"
    lines << ""

    PHASE_ORDER.each do |phase_name|
      tasks = phases[phase_name] || []
      next if tasks.empty?

      lines << "## #{PHASE_LABELS[phase_name]}"
      lines << ""
      tasks.each do |task|
        check = task.completed ? "x" : " "
        lines << "- [#{check}] **#{task.title}**"
        lines << "  - *Owner:* #{task.owner_type}  ·  *Effort:* #{task.effort_estimate}"
        lines << "  - *Success indicator:* #{task.success_indicator}"
        lines << ""
      end
    end

    lines.join("\n")
  end

  def growth_cycle_params
    params.require(:growth_cycle).permit(:organization_name, :name, :time_period, :goal_description, :audience_description)
  end
end
