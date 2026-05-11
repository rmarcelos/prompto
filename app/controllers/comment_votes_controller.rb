class CommentVotesController < ApplicationController
  before_action :require_user
  before_action :set_prompt
  before_action :set_comment

  def create
    vote = @comment.comment_votes.find_or_initialize_by(user: current_user)
    vote.value = vote_value

    if vote.save
      message = t('comment_votes.flashes.create.success')

      respond_to do |format|
        format.html do
          flash[:success] = message
          redirect_to prompt_path(@prompt, anchor: 'comments-section')
        end

        format.json do
          prepare_comments_section_context
          render json: {
            comments_section_html: render_to_string(partial: 'prompts/comments_section', formats: [:html]),
            message: message,
            message_type: 'success'
          }
        end
      end
    else
      message = vote.errors.full_messages.to_sentence

      respond_to do |format|
        format.html do
          flash[:error] = message
          redirect_to prompt_path(@prompt, anchor: 'comments-section')
        end

        format.json do
          prepare_comments_section_context
          render json: {
            comments_section_html: render_to_string(partial: 'prompts/comments_section', formats: [:html]),
            message: message,
            message_type: 'error'
          }, status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    vote = @comment.comment_votes.find_by!(user: current_user)
    vote.destroy

    message = t('comment_votes.flashes.destroy.success')

    respond_to do |format|
      format.html do
        flash[:info] = message
        redirect_to prompt_path(@prompt, anchor: 'comments-section')
      end

      format.json do
        prepare_comments_section_context
        render json: {
          comments_section_html: render_to_string(partial: 'prompts/comments_section', formats: [:html]),
          message: message,
          message_type: 'info'
        }
      end
    end
  end

  private

  def set_prompt
    @prompt = Prompt.find_by_param!(params[:prompt_id])
  end

  def set_comment
    @comment = @prompt.comments.find(params[:comment_id])
  end

  def vote_value
    submitted_value = params[:value].to_i
    return submitted_value if [-1, 1].include?(submitted_value)

    1
  end

  def prepare_comments_section_context
    @comments = @prompt.comments.includes(:creator, :comment_votes).most_voted_first
    @existing_comment = @comments.find { |comment| comment.creator_id == current_user&.id }
    @comment = Comment.new(prompt: @prompt)
  end
end