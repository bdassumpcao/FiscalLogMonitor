type Props = {
  totalLogs: number;
  totalErrorTypes: number;
  totalSessions: number;
};

export function SummaryCards({ totalLogs, totalErrorTypes, totalSessions }: Props) {
  return (
    <section className="summary-grid">
      <article className="card">
        <h3>Total de Logs</h3>
        <p>{totalLogs}</p>
      </article>
      <article className="card">
        <h3>Tipos de Erro</h3>
        <p>{totalErrorTypes}</p>
      </article>
      <article className="card">
        <h3>Sessoes</h3>
        <p>{totalSessions}</p>
      </article>
    </section>
  );
}
