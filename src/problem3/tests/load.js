import http from "k6/http";

const constantRate = {
  executor: "constant-arrival-rate",
  rate: Number(__ENV.RATE || 200),
  timeUnit: "1s",
  duration: __ENV.DURATION || "60s",
  preAllocatedVUs: 100,
  maxVUs: Number(__ENV.MAX_VUS || 800),
};

const closedLoop = {
  executor: "constant-vus",
  vus: Number(__ENV.VUS || 120),
  duration: __ENV.DURATION || "60s",
};

export const options = {
  discardResponseBodies: true,
  scenarios: {
    load: __ENV.EXECUTOR === "vus" ? closedLoop : constantRate,
  },
};

export default function () {
  http.get(`${__ENV.TARGET}/api/users`, { timeout: "15s" });
}
