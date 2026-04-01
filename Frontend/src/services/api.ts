export const API_BASE = "http://192.168.100.108:9100/ServidorLog";

export type Summary = {
  totalLogs: number;
  totalErrorTypes: number;
  totalSessions: number;
};

export type ErrorGroup = {
  exceptionClass: string;
  severity: string;
  count: number;
};

export type DailyMetric = {
  date: string;
  count: number;
};

export type SessionMetric = {
  sessionId: string;
  count: number;
};

export type CallbackMetric = {
  callback: string;
  count: number;
};

export type Recommendation = {
  exceptionClass: string;
  message: string;
  severity: string;
  count: number;
  suggestion: string;
};

export type LogDetail = {
  id: number;
  exceptionTime: string;
  exceptionClass: string;
  exceptionMessage: string;
  sessionId: string;
  callbackName: string;
  clientIp: string;
  activeForm: string;
  requestPath: string;
  severity: string;
};

export type LogDetailFull = LogDetail & {
  stackTrace: string;
  rawText: string;
};

export type ServerLifecycleDaily = {
  date: string;
  startCount: number;
  corsCount: number;
};

export type ServerLifecycleEvent = {
  id: number;
  eventTime: string;
  eventType: "SERVER_START" | "CORS_WARNING" | string;
  httpPort: number;
  httpsPort: number;
  message: string;
};

export async function getSummary() {
  const res = await fetch(`${API_BASE}/logs/summary`);
  if (!res.ok) throw new Error("Failed to fetch summary");
  return (await res.json()) as Summary;
}

export async function getErrors() {
  const res = await fetch(`${API_BASE}/logs/errors`);
  if (!res.ok) throw new Error("Failed to fetch errors");
  return (await res.json()) as ErrorGroup[];
}

export async function getDailyMetrics() {
  const res = await fetch(`${API_BASE}/logs/metrics/daily`);
  if (!res.ok) throw new Error("Failed to fetch daily metrics");
  return (await res.json()) as DailyMetric[];
}

export async function getSessionMetrics() {
  const res = await fetch(`${API_BASE}/logs/metrics/session`);
  if (!res.ok) throw new Error("Failed to fetch session metrics");
  return (await res.json()) as SessionMetric[];
}

export async function getCallbackMetrics() {
  const res = await fetch(`${API_BASE}/logs/metrics/callback`);
  if (!res.ok) throw new Error("Failed to fetch callback metrics");
  return (await res.json()) as CallbackMetric[];
}

export async function getRecommendations() {
  const res = await fetch(`${API_BASE}/logs/recommendations`);
  if (!res.ok) throw new Error("Failed to fetch recommendations");
  return (await res.json()) as Recommendation[];
}

export async function getLogDetails(filter: "error" | "day" | "session" | "callback", value: string) {
  const url = `${API_BASE}/logs/details?filter=${encodeURIComponent(filter)}&value=${encodeURIComponent(value)}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error("Failed to fetch log details");
  return (await res.json()) as LogDetail[];
}

export async function getLogDetailById(id: number) {
  const res = await fetch(`${API_BASE}/logs/details/${id}`);
  if (!res.ok) throw new Error("Failed to fetch full log detail");
  return (await res.json()) as LogDetailFull;
}

export async function getServerLifecycleDaily() {
  const res = await fetch(`${API_BASE}/logs/server-lifecycle/daily`);
  if (!res.ok) throw new Error("Failed to fetch server lifecycle daily");
  return (await res.json()) as ServerLifecycleDaily[];
}

export async function getServerLifecycleEvents(day?: string, type?: string) {
  const params = new URLSearchParams();
  if (day) params.set("day", day);
  if (type) params.set("type", type);

  const suffix = params.toString();
  const url = `${API_BASE}/logs/server-lifecycle/events${suffix ? `?${suffix}` : ""}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error("Failed to fetch server lifecycle events");
  return (await res.json()) as ServerLifecycleEvent[];
}
