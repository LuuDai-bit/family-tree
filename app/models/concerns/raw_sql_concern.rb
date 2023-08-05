module RawSqlConcern
  extend ActiveSupport::Concern

  def execute_sql(*sql_array)
    connection.execute send(:sanitize_sql_array, sql_array)
  end
end
