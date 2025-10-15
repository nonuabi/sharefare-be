# frozen_string_literal: true

class ExpensesController < GroupsController
  before_action :find_group, only: %i[index create]

  def index
    expenses = @group.expenses.includes(:split_expenses).order(created_at: :desc)
    render json: { expenses: expenses.as_json(include: :split_expenses) }, status: :ok
  rescue StandardError => e
    Rails.logger.info { "Expenses not able to be fetched: #{e.full_message}" }
    render json: { error: 'Error fetching expenses', message: e.message }, status: :unprocessable_entity
  end

  def create
    expense = @group.expenses.create!(
      paid_amount: expense_params[:amount],
      description: expense_params[:description],
      notes: expense_params[:notes],
      payer_id: @group.users.find_by(id: expense_params[:paidBy])&.id,
      creator_id: @current_user.id
    )
    splits = expense_params[:splitBetween]
    if splits.present?
      split_amount = split_amount(expense_params[:amount], splits.size)
      splits.each do |user_id|
        if user_id.to_i == expense_params[:paidBy].to_i
          expense.split_expenses.create!(user_id: user_id, paid_amount: split_amount, due_amount: 0.0)
        else
          expense.split_expenses.create!(user_id: user_id, paid_amount: 0.0, due_amount: split_amount)
        end
      end
    else
      group_members = @group.users
      split_amount = split_amount(expense_params[:amount], group_members.size)
      group_members.each do |user|
        if user.id == expense_params[:paidBy].to_i
          expense.split_expenses.create!(user_id: user.id, paid_amount: split_amount, due_amount: 0.0)
        else
          expense.split_expenses.create!(user_id: user.id, paid_amount: 0.0, due_amount: split_amount)
        end
      end
    end

    render json: { message: 'Expense created successfully', expense: expense }, status: :created
  rescue StandardError => e
    Rails.logger.info { "Expense not able to be created: #{e.full_message}" }
    render json: { error: 'Error creating expense', message: e.message }, status: :unprocessable_entity
  end

  private

  def expense_params
    params.require(:expense).permit(:amount, :description, :notes, :paidBy, splitBetween: [])
  end

  def split_amount(amount, size)
    (amount.to_f / size).round(2)
  end
end
