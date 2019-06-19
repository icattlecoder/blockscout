defmodule Explorer.Repo.Migrations.ReduceTransactionStatusConstraint do
  use Ecto.Migration

  def change do
    drop(
      constraint(
        :transactions,
        :status
      )
    )

    create(
      constraint(
        :transactions,
        :status,
        # NOTE: all checks on status lifted except that if error is not null
        # then the status must be 0.
        # This is because of block invalidation, that cause transactions to be
        # refetched while previous internal transactions still exist
        check: """
        (error IS NULL) OR
        (status = 0 and error = 'dropped/replaced')
        """
      )
    )
  end
end
