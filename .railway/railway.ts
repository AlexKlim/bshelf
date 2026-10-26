import { defineRailway, github, project, service } from "railway/iac";
// This repository manages only its own resources in the environment. Other
// repositories export their own partial name.
// See https://docs.railway.com/infrastructure-as-code#multi-repo-projects
export const partial = "web";
export default defineRailway(() => {
  const web = service("web", {
    source: github("AlexKlim/bshelf", { branch: "main", checkSuites: false }),
    build: { buildEnvironment: "V3", builder: "DOCKERFILE", dockerfilePath: "Dockerfile" },
    healthcheck: "/up",
    replicas: { "europe-west4-drams3a": 1 },
    domains: [{ domain: "bshelf.org", port: 3000 }, { domain: "www.bshelf.org", port: 3000 }],
  });

  return project("bshelf", {
    variables: { managed: false },
    resources: [web],
  });
});
