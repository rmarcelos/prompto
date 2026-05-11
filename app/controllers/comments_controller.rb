class CommentsController < ApplicationController
  before_action :require_user
  before_action :set_prompt

  def create
    @comment = @prompt.comments.build(comment_params)
    @comment.creator = current_user
    @comment.updater = current_user

    if @comment.save
      message = t('comments.flashes.create.success')
      respond_to do |format|
        format.html do
          flash[:success] = message
          redirect_to prompt_path(@prompt, anchor: 'comments-section')
        end

        format.json do
          prepare_comments_section_context(existing_comment: @comment)
          render json: {
            comments_section_html: render_to_string(partial: 'prompts/comments_section', formats: [:html]),
            message: message,
            message_type: 'success'
          }
        end
      end
    else
      message = comment_error_message

      respond_to do |format|
        format.html do
          flash[:error] = message
          redirect_to prompt_path(@prompt, anchor: 'comments-section')
        end

        format.json do
          prepare_comments_section_context(existing_comment: @prompt.comments.find_by(creator_id: current_user.id))
          render json: {
            comments_section_html: render_to_string(partial: 'prompts/comments_section', formats: [:html]),
            message: message,
            message_type: 'error'
          }, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def set_prompt
    @prompt = Prompt.find_by_param!(params[:prompt_id])
  end

  def comment_params
    params.require(:comment).permit(:content)
  end

  def prepare_comments_section_context(existing_comment: nil)
    @comments = @prompt.comments.includes(:creator, :comment_votes).most_voted_first
    @existing_comment = existing_comment
    @comment = Comment.new(prompt: @prompt) unless @existing_comment.present?
  end

  def comment_error_message
    creator_errors = @comment.errors.messages_for(:creator_id)
    creator_errors.present? ? creator_errors.to_sentence : @comment.errors.full_messages.to_sentence
  end
end