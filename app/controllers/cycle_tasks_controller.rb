class CycleTasksController < ApplicationController
  include ActionView::RecordIdentifier

  def toggle
    growth_cycle = current_user.growth_cycles.find(params[:growth_cycle_id])
    task = growth_cycle.cycle_tasks.find(params[:id])
    task.update!(completed: !task.completed)

    render turbo_stream: turbo_stream.update(
      dom_id(task),
      partial: "growth_cycles/task_item",
      locals:  { task: task, growth_cycle: growth_cycle }
    )
  end
end
