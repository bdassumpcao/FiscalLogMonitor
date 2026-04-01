import { useEffect, useState } from "react";
import {
  CallbackMetric,
  DailyMetric,
  ErrorGroup,
  LogDetail,
  LogDetailFull,
  Recommendation,
  ServerLifecycleDaily,
  ServerLifecycleEvent,
  SessionMetric,
  Summary,
  getCallbackMetrics,
  getDailyMetrics,
  getLogDetailById,
  getErrors,
  getLogDetails,
  getRecommendations,
  getServerLifecycleDaily,
  getServerLifecycleEvents,
  getSessionMetrics,
  getSummary,
} from "../services/api";
import { SummaryCards } from "../components/SummaryCards";

type TabKey = "errors" | "daily" | "session" | "callback" | "recommendations" | "serverLifecycle";
type StackViewMode = "stackTrace" | "rawText";
type ServerLifecycleSubTab = "starts" | "cors";

export default function Dashboard() {
  const [summary, setSummary] = useState<Summary | null>(null);
  const [errors, setErrors] = useState<ErrorGroup[]>([]);
  const [daily, setDaily] = useState<DailyMetric[]>([]);
  const [sessions, setSessions] = useState<SessionMetric[]>([]);
  const [callbacks, setCallbacks] = useState<CallbackMetric[]>([]);
  const [recommendations, setRecommendations] = useState<Recommendation[]>([]);
  const [serverLifecycleDaily, setServerLifecycleDaily] = useState<ServerLifecycleDaily[]>([]);
  const [serverLifecycleSubTab, setServerLifecycleSubTab] =
    useState<ServerLifecycleSubTab>("starts");
  const [isLifecycleModalOpen, setIsLifecycleModalOpen] = useState(false);
  const [lifecycleModalLoading, setLifecycleModalLoading] = useState(false);
  const [lifecycleModalError, setLifecycleModalError] = useState("");
  const [lifecycleModalEvents, setLifecycleModalEvents] = useState<ServerLifecycleEvent[]>([]);
  const [lifecycleModalDayFilter, setLifecycleModalDayFilter] = useState("");
  const [activeTab, setActiveTab] = useState<TabKey>("errors");
  const [severityFilter, setSeverityFilter] = useState("all");
  const [query, setQuery] = useState("");
  const [isLoadingSummary, setIsLoadingSummary] = useState(true);
  const [summaryError, setSummaryError] = useState("");
  const [isLoadingTab, setIsLoadingTab] = useState(false);
  const [tabError, setTabError] = useState("");
  const [loadedTabs, setLoadedTabs] = useState<Record<TabKey, boolean>>({
    errors: false,
    daily: false,
    session: false,
    callback: false,
    recommendations: false,
    serverLifecycle: false,
  });
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [modalTitle, setModalTitle] = useState("Detalhes");
  const [modalLoading, setModalLoading] = useState(false);
  const [modalError, setModalError] = useState("");
  const [modalDetails, setModalDetails] = useState<LogDetail[]>([]);
  const [modalSeverityFilter, setModalSeverityFilter] = useState("all");
  const [modalQuery, setModalQuery] = useState("");
  const [isStackModalOpen, setIsStackModalOpen] = useState(false);
  const [stackModalLoading, setStackModalLoading] = useState(false);
  const [stackModalError, setStackModalError] = useState("");
  const [stackDetail, setStackDetail] = useState<LogDetailFull | null>(null);
  const [stackViewMode, setStackViewMode] = useState<StackViewMode>("rawText");

  useEffect(() => {
    async function loadSummary() {
      setIsLoadingSummary(true);
      setSummaryError("");

      try {
        const summaryData = await getSummary();
        setSummary(summaryData);
      } catch (error) {
        setSummaryError("Falha ao carregar resumo da API.");
        console.error(error);
      } finally {
        setIsLoadingSummary(false);
      }
    }

    loadSummary();
  }, []);

  useEffect(() => {
    void loadTab(activeTab);
  }, [activeTab]);

  async function loadTab(tab: TabKey, force = false) {
    if (!force && loadedTabs[tab]) return;

    setIsLoadingTab(true);
    setTabError("");

    try {
      if (tab === "errors") {
        setErrors(await getErrors());
      } else if (tab === "daily") {
        setDaily(await getDailyMetrics());
      } else if (tab === "session") {
        setSessions(await getSessionMetrics());
      } else if (tab === "callback") {
        setCallbacks(await getCallbackMetrics());
      } else if (tab === "recommendations") {
        setRecommendations(await getRecommendations());
      } else if (tab === "serverLifecycle") {
        const dailyData = await getServerLifecycleDaily();
        setServerLifecycleDaily(dailyData);
        setServerLifecycleSubTab("starts");
      }

      setLoadedTabs((prev) => ({ ...prev, [tab]: true }));
    } catch (error) {
      setTabError("Falha ao carregar dados da aba selecionada.");
      console.error(error);
    } finally {
      setIsLoadingTab(false);
    }
  }

  function refreshActiveTab() {
    void loadTab(activeTab, true);
  }

  const filteredRecommendations = recommendations.filter((item) => {
    const matchesSeverity =
      severityFilter === "all" || item.severity.toLowerCase() === severityFilter;
    const matchesQuery =
      query.trim() === "" ||
      item.exceptionClass.toLowerCase().includes(query.toLowerCase()) ||
      item.message.toLowerCase().includes(query.toLowerCase()) ||
      item.suggestion.toLowerCase().includes(query.toLowerCase());

    return matchesSeverity && matchesQuery;
  });

  async function openDetails(
    filter: "error" | "day" | "session" | "callback",
    value: string,
    title: string,
  ) {
    setIsModalOpen(true);
    setModalTitle(title);
    setModalLoading(true);
    setModalError("");
    setModalSeverityFilter("all");
    setModalQuery("");
    setModalDetails([]);

    try {
      const details = await getLogDetails(filter, value);
      setModalDetails(details);
    } catch (error) {
      setModalError("Falha ao carregar detalhes da selecao.");
      console.error(error);
    } finally {
      setModalLoading(false);
    }
  }

  async function openStackTrace(id: number) {
    setIsStackModalOpen(true);
    setStackModalLoading(true);
    setStackModalError("");
    setStackDetail(null);
    setStackViewMode("rawText");

    try {
      const detail = await getLogDetailById(id);
      setStackDetail(detail);
    } catch (error) {
      setStackModalError("Falha ao carregar stacktrace completo.");
      console.error(error);
    } finally {
      setStackModalLoading(false);
    }
  }

  const filteredModalDetails = modalDetails.filter((item) => {
    const severity = (item.severity || "").toLowerCase();
    const msg = (item.exceptionMessage || "").toLowerCase();
    const cls = (item.exceptionClass || "").toLowerCase();
    const ses = (item.sessionId || "").toLowerCase();
    const cb = (item.callbackName || "").toLowerCase();
    const q = modalQuery.toLowerCase().trim();

    const matchesSeverity = modalSeverityFilter === "all" || severity === modalSeverityFilter;
    const matchesText =
      q === "" || msg.includes(q) || cls.includes(q) || ses.includes(q) || cb.includes(q);

    return matchesSeverity && matchesText;
  });

  function hasUnitReference(line: string) {
    return /[A-Za-z0-9_]+\.pas/i.test(line);
  }

  async function openServerLifecycleDetails(day?: string) {
    try {
      setIsLifecycleModalOpen(true);
      setLifecycleModalLoading(true);
      setLifecycleModalError("");
      setLifecycleModalEvents([]);
      setLifecycleModalDayFilter(day || "");
      const type = getLifecycleTypeFilter(serverLifecycleSubTab);
      const events = await getServerLifecycleEvents(day, type);
      setLifecycleModalEvents(events);
    } catch (error) {
      setLifecycleModalError("Falha ao carregar eventos de lifecycle do servidor.");
      console.error(error);
    } finally {
      setLifecycleModalLoading(false);
    }
  }

  function getLifecycleTypeFilter(subTab: ServerLifecycleSubTab) {
    return subTab === "starts" ? "SERVER_START" : "CORS_WARNING";
  }

  async function changeServerLifecycleSubTab(nextSubTab: ServerLifecycleSubTab) {
    setServerLifecycleSubTab(nextSubTab);

    if (isLifecycleModalOpen) {
      try {
        setLifecycleModalLoading(true);
        setLifecycleModalError("");
        const events = await getServerLifecycleEvents(
          lifecycleModalDayFilter || undefined,
          getLifecycleTypeFilter(nextSubTab),
        );
        setLifecycleModalEvents(events);
      } catch (error) {
        setLifecycleModalError("Falha ao carregar eventos de lifecycle do servidor.");
        console.error(error);
      } finally {
        setLifecycleModalLoading(false);
      }
    }
  }

  function getRestartStatus(startCount: number) {
    if (startCount <= 1) {
      return { label: "ok", badgeClass: "badge-low" };
    }

    if (startCount <= 3) {
      return { label: "alerta", badgeClass: "badge-medium" };
    }

    return { label: "atencao", badgeClass: "badge-high" };
  }

  function renderPanelHeader(title: string) {
    return (
      <div className="panel-header">
        <h2>{title}</h2>
        <button className="refresh-btn" onClick={refreshActiveTab}>
          Atualizar
        </button>
      </div>
    );
  }

  function renderTabContent() {
    if (activeTab === "errors") {
      return (
        <section className="card panel">
          {renderPanelHeader("Erros por classe")}
          <table>
            <thead>
              <tr>
                <th>Classe</th>
                <th>Severidade</th>
                <th>Quantidade</th>
              </tr>
            </thead>
            <tbody>
              {errors.map((item) => (
                <tr
                  key={item.exceptionClass}
                  className="clickable-row"
                  onClick={() =>
                    openDetails(
                      "error",
                      item.exceptionClass || "",
                      `Detalhes da classe ${item.exceptionClass}`,
                    )
                  }
                >
                  <td>{item.exceptionClass || "(vazio)"}</td>
                  <td>
                    <span className={`badge badge-${(item.severity || "low").toLowerCase()}`}>
                      {item.severity || "low"}
                    </span>
                  </td>
                  <td>{item.count}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      );
    }

    if (activeTab === "daily") {
      return (
        <section className="card panel">
          {renderPanelHeader("Ocorrencias por dia")}
          <table>
            <thead>
              <tr>
                <th>Data</th>
                <th>Quantidade</th>
              </tr>
            </thead>
            <tbody>
              {daily.map((item) => (
                <tr
                  key={item.date}
                  className="clickable-row"
                  onClick={() => openDetails("day", item.date, `Detalhes do dia ${item.date}`)}
                >
                  <td>{item.date}</td>
                  <td>{item.count}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      );
    }

    if (activeTab === "session") {
      return (
        <section className="card panel">
          {renderPanelHeader("Ocorrencias por sessao")}
          <table>
            <thead>
              <tr>
                <th>Session ID</th>
                <th>Quantidade</th>
              </tr>
            </thead>
            <tbody>
              {sessions.map((item) => (
                <tr
                  key={item.sessionId}
                  className="clickable-row"
                  onClick={() =>
                    openDetails("session", item.sessionId, `Detalhes da sessao ${item.sessionId}`)
                  }
                >
                  <td>{item.sessionId}</td>
                  <td>{item.count}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      );
    }

    if (activeTab === "callback") {
      return (
        <section className="card panel">
          {renderPanelHeader("Ocorrencias por callback")}
          <table>
            <thead>
              <tr>
                <th>Callback</th>
                <th>Quantidade</th>
              </tr>
            </thead>
            <tbody>
              {callbacks.map((item) => (
                <tr
                  key={item.callback}
                  className="clickable-row"
                  onClick={() =>
                    openDetails("callback", item.callback, `Detalhes do callback ${item.callback}`)
                  }
                >
                  <td>{item.callback}</td>
                  <td>{item.count}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      );
    }

    if (activeTab === "serverLifecycle") {
      return (
        <section className="card panel">
          {renderPanelHeader("Ciclo de vida do servidor (FiscalFacilWeb.log)")}

          <div className="server-lifecycle-subtabs" role="tablist" aria-label="Eventos do servidor">
            <button
              role="tab"
              className={serverLifecycleSubTab === "starts" ? "active" : ""}
              onClick={() => void changeServerLifecycleSubTab("starts")}
            >
              Apenas inicializacoes
            </button>
            <button
              role="tab"
              className={serverLifecycleSubTab === "cors" ? "active" : ""}
              onClick={() => void changeServerLifecycleSubTab("cors")}
            >
              Apenas CORS
            </button>
            <button className="clear-filter" onClick={() => void openServerLifecycleDetails()}>
              Ver detalhes (todos os dias)
            </button>
          </div>

          <h3>Resumo diario</h3>
          <table>
            <thead>
              <tr>
                <th>Data</th>
                <th>Inicializacoes</th>
                <th>CORS warnings</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {serverLifecycleDaily.map((item) => (
                <tr
                  key={item.date}
                  className="clickable-row"
                  onClick={() => void openServerLifecycleDetails(item.date)}
                >
                  <td>{item.date}</td>
                  <td>{item.startCount}</td>
                  <td>{item.corsCount}</td>
                  <td>
                    <span className={`badge ${getRestartStatus(item.startCount).badgeClass}`}>
                      {getRestartStatus(item.startCount).label}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      );
    }

    return (
      <section className="card panel">
        {renderPanelHeader("Recomendacoes automaticas")}

        <div className="toolbar">
          <label>
            Severidade
            <select value={severityFilter} onChange={(e) => setSeverityFilter(e.target.value)}>
              <option value="all">Todas</option>
              <option value="critical">Critical</option>
              <option value="high">High</option>
              <option value="medium">Medium</option>
              <option value="low">Low</option>
            </select>
          </label>

          <label>
            Busca
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="classe, mensagem ou sugestao"
            />
          </label>
        </div>

        <table>
          <thead>
            <tr>
              <th>Classe</th>
              <th>Severidade</th>
              <th>Ocorrencias</th>
              <th>Sugestao</th>
            </tr>
          </thead>
          <tbody>
            {filteredRecommendations.map((item, index) => (
              <tr key={`${item.exceptionClass}-${index}`}>
                <td>{item.exceptionClass}</td>
                <td>
                  <span className={`badge badge-${item.severity.toLowerCase()}`}>
                    {item.severity}
                  </span>
                </td>
                <td>{item.count}</td>
                <td>{item.suggestion}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    );
  }

  return (
    <main className="dashboard">
      <header className="hero card">
        <p className="kicker">Fiscal Facil</p>
        <h1>Observatorio de Logs</h1>
        <p>
          Visao centralizada de excecoes por periodo, sessao e callback com recomendacoes
          automaticas para acelerar diagnostico.
        </p>
      </header>

      {summary && (
        <SummaryCards
          totalLogs={summary.totalLogs}
          totalErrorTypes={summary.totalErrorTypes}
          totalSessions={summary.totalSessions}
        />
      )}

      <nav className="tabs" aria-label="Metricas">
        <button
          className={activeTab === "errors" ? "active" : ""}
          onClick={() => setActiveTab("errors")}
        >
          Erros
        </button>
        <button
          className={activeTab === "daily" ? "active" : ""}
          onClick={() => setActiveTab("daily")}
        >
          Diario
        </button>
        <button
          className={activeTab === "session" ? "active" : ""}
          onClick={() => setActiveTab("session")}
        >
          Sessao
        </button>
        <button
          className={activeTab === "callback" ? "active" : ""}
          onClick={() => setActiveTab("callback")}
        >
          Callback
        </button>
        <button
          className={activeTab === "recommendations" ? "active" : ""}
          onClick={() => setActiveTab("recommendations")}
        >
          Recomendacoes
        </button>
        <button
          className={activeTab === "serverLifecycle" ? "active" : ""}
          onClick={() => setActiveTab("serverLifecycle")}
        >
          Servidor
        </button>
      </nav>

      {isLoadingSummary && <section className="card panel">Carregando resumo...</section>}
      {summaryError && <section className="card panel error">{summaryError}</section>}
      {isLoadingTab && <section className="card panel">Carregando dados da aba...</section>}
      {tabError && <section className="card panel error">{tabError}</section>}
      {!isLoadingTab && !tabError && renderTabContent()}

      {isModalOpen && (
        <div className="modal-overlay" onClick={() => setIsModalOpen(false)}>
          <section className="modal card" onClick={(e) => e.stopPropagation()}>
            <header className="modal-header">
              <h3>{modalTitle}</h3>
              <button onClick={() => setIsModalOpen(false)}>Fechar</button>
            </header>

            {modalLoading && <p>Carregando sublista...</p>}
            {modalError && <p className="error-text">{modalError}</p>}

            {!modalLoading && !modalError && (
              <>
                <div className="toolbar modal-toolbar">
                  <label>
                    Severidade
                    <select
                      value={modalSeverityFilter}
                      onChange={(e) => setModalSeverityFilter(e.target.value)}
                    >
                      <option value="all">Todas</option>
                      <option value="critical">Critical</option>
                      <option value="high">High</option>
                      <option value="medium">Medium</option>
                      <option value="low">Low</option>
                    </select>
                  </label>

                  <label>
                    Busca
                    <input
                      value={modalQuery}
                      onChange={(e) => setModalQuery(e.target.value)}
                      placeholder="classe, mensagem, sessao ou callback"
                    />
                  </label>
                </div>

                <div className="modal-table-wrap">
                  <table>
                    <thead>
                      <tr>
                        <th>Data/Hora</th>
                        <th>Classe</th>
                        <th>Mensagem</th>
                        <th>Sessao</th>
                        <th>Callback</th>
                        <th>Severidade</th>
                      </tr>
                    </thead>
                    <tbody>
                      {filteredModalDetails.map((detail) => (
                        <tr
                          key={detail.id}
                          className="clickable-row"
                          onClick={() => openStackTrace(detail.id)}
                        >
                          <td>{detail.exceptionTime || "-"}</td>
                          <td>{detail.exceptionClass || "-"}</td>
                          <td>{detail.exceptionMessage || "-"}</td>
                          <td>{detail.sessionId || "-"}</td>
                          <td>{detail.callbackName || "-"}</td>
                          <td>{detail.severity || "-"}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </>
            )}
          </section>
        </div>
      )}

      {isStackModalOpen && (
        <div className="modal-overlay" onClick={() => setIsStackModalOpen(false)}>
          <section className="modal card stack-modal" onClick={(e) => e.stopPropagation()}>
            <header className="modal-header">
              <h3>Stacktrace Completo</h3>
              <button onClick={() => setIsStackModalOpen(false)}>Fechar</button>
            </header>

            {stackModalLoading && <p>Carregando stacktrace...</p>}
            {stackModalError && <p className="error-text">{stackModalError}</p>}

            {!stackModalLoading && !stackModalError && stackDetail && (
              <div className="stack-content">
                <p>
                  <strong>Classe:</strong> {stackDetail.exceptionClass || "-"}
                </p>
                <p>
                  <strong>Mensagem:</strong> {stackDetail.exceptionMessage || "-"}
                </p>
                <div className="stack-toggle">
                  <button
                    className={stackViewMode === "rawText" ? "active" : ""}
                    onClick={() => setStackViewMode("rawText")}
                  >
                    rawText
                  </button>
                  <button
                    className={stackViewMode === "stackTrace" ? "active" : ""}
                    onClick={() => setStackViewMode("stackTrace")}
                  >
                    stackTrace
                  </button>
                </div>

                <pre className="stack-pre">
                  {(stackViewMode === "stackTrace"
                    ? stackDetail.stackTrace
                    : stackDetail.rawText || ""
                  )
                    .split(/\r?\n/)
                    .map((line, index) => (
                      <span
                        key={index}
                        className={
                          hasUnitReference(line) ? "stack-line highlight-unit" : "stack-line"
                        }
                      >
                        {line || " "}
                        {"\n"}
                      </span>
                    ))}
                </pre>
              </div>
            )}
          </section>
        </div>
      )}

      {isLifecycleModalOpen && (
        <div className="modal-overlay" onClick={() => setIsLifecycleModalOpen(false)}>
          <section className="modal card" onClick={(e) => e.stopPropagation()}>
            <header className="modal-header">
              <h3>
                Eventos do servidor
                {serverLifecycleSubTab === "starts" ? " (inicializacoes)" : " (CORS)"}
                {lifecycleModalDayFilter ? ` - dia ${lifecycleModalDayFilter}` : " - todos os dias"}
              </h3>
              <button onClick={() => setIsLifecycleModalOpen(false)}>Fechar</button>
            </header>

            {lifecycleModalLoading && <p>Carregando eventos...</p>}
            {lifecycleModalError && <p className="error-text">{lifecycleModalError}</p>}

            {!lifecycleModalLoading && !lifecycleModalError && (
              <div className="modal-table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th>Data/Hora</th>
                      <th>Tipo</th>
                      <th>HTTP</th>
                      <th>HTTPS</th>
                      <th>Mensagem</th>
                    </tr>
                  </thead>
                  <tbody>
                    {lifecycleModalEvents.map((item) => (
                      <tr key={item.id}>
                        <td>{item.eventTime}</td>
                        <td>
                          <span
                            className={`badge ${item.eventType === "SERVER_START" ? "badge-low" : "badge-medium"}`}
                          >
                            {item.eventType}
                          </span>
                        </td>
                        <td>{item.httpPort || "-"}</td>
                        <td>{item.httpsPort || "-"}</td>
                        <td>{item.message}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        </div>
      )}
    </main>
  );
}
