# Workers — Deep-dive (auditoria 29/04 noite)

## Arquivos worker

### Localização e tamanho
```
7675 /root/Zapflix-Tech/apps/worker/src/worker.ts
1 /root/Zapflix-Tech/node_modules/.ignored/vitest/worker.d.ts
784 /root/Zapflix-Tech/node_modules/.ignored/@types/node/worker_threads.d.ts
32 /root/Zapflix-Tech/node_modules/.ignored/vitest/dist/worker.d.ts
715 /root/Zapflix-Tech/node_modules/webdriver/node_modules/@types/node/worker_threads.d.ts
715 /root/Zapflix-Tech/node_modules/webdriverio/node_modules/@types/node/worker_threads.d.ts
255 /root/Zapflix-Tech/node_modules/.ignored/vitest/dist/chunks/worker.d.Dyxm8DEL.d.ts
286 /root/Zapflix-Tech/node_modules/.ignored/bullmq/dist/esm/classes/worker.d.ts
143 /root/Zapflix-Tech/node_modules/.ignored/bullmq/dist/esm/interfaces/worker-options.d.ts
3 /root/Zapflix-Tech/node_modules/.ignored/next/dist/export/worker.d.ts
35 /root/Zapflix-Tech/node_modules/.ignored/next/dist/lib/worker.d.ts
3 /root/Zapflix-Tech/node_modules/.ignored/next/dist/build/worker.d.ts
1 /root/Zapflix-Tech/checkout/node_modules/modern-screenshot/worker.d.ts
1 /root/Zapflix-Tech/node_modules/.ignored/next/dist/server/lib/worker-utils.d.ts
41 /root/Zapflix-Tech/checkout/node_modules/langium/src/node/worker-thread-async-parser.ts
17 /root/Zapflix-Tech/checkout/node_modules/langium/lib/node/worker-thread-async-parser.d.ts
0 /root/Zapflix-Tech/checkout/node_modules/tinypool/dist/entry/worker.d.ts
1 /root/Zapflix-Tech/checkout/node_modules/.ignored_vitest/workers.d.ts
37 /root/Zapflix-Tech/checkout/node_modules/.ignored_vitest/dist/workers.d.ts
894 /root/Zapflix-Tech/checkout/node_modules/@types/.ignored_node/worker_threads.d.ts
156 /root/Zapflix-Tech/checkout/node_modules/.ignored_vitest/dist/chunks/worker.tN5KGIih.d.ts
8 /root/Zapflix-Tech/checkout/node_modules/.ignored_vitest/dist/chunks/worker.B9FxPCaC.d.ts
1 /root/Zapflix-Tech/checkout/node_modules/.pnpm/vitest@2.1.9_@types+node@24.7.0_lightningcss@1.30.1/node_modules/vitest/workers.d.ts
1 /root/Zapflix-Tech/checkout/node_modules/.pnpm/modern-screenshot@4.6.6/node_modules/modern-screenshot/worker.d.ts
18 /root/Zapflix-Tech/checkout/node_modules/.pnpm/langium@3.3.1/node_modules/langium/lib/node/worker-thread-async-parser.d.ts
41 /root/Zapflix-Tech/checkout/node_modules/.pnpm/langium@3.3.1/node_modules/langium/src/node/worker-thread-async-parser.ts
821 /root/Zapflix-Tech/checkout/node_modules/.pnpm/@types+node@24.7.0/node_modules/@types/node/worker_threads.d.ts
0 /root/Zapflix-Tech/checkout/node_modules/.pnpm/tinypool@1.1.1/node_modules/tinypool/dist/entry/worker.d.ts
37 /root/Zapflix-Tech/checkout/node_modules/.pnpm/vitest@2.1.9_@types+node@24.7.0_lightningcss@1.30.1/node_modules/vitest/dist/workers.d.ts
156 /root/Zapflix-Tech/checkout/node_modules/.pnpm/vitest@2.1.9_@types+node@24.7.0_lightningcss@1.30.1/node_modules/vitest/dist/chunks/worker.tN5KGIih.d.ts
8 /root/Zapflix-Tech/checkout/node_modules/.pnpm/vitest@2.1.9_@types+node@24.7.0_lightningcss@1.30.1/node_modules/vitest/dist/chunks/worker.B9FxPCaC.d.ts
784 /root/Zapflix-Tech/node_modules/.pnpm/@types+node@22.19.8/node_modules/@types/node/worker_threads.d.ts
35 /root/Zapflix-Tech/node_modules/.pnpm/next@16.0.10_@opentelemetry+api@1.9.0_react-dom@19.2.0_react@19.2.0__react@19.2.0/node_modules/next/dist/lib/worker.d.ts
3 /root/Zapflix-Tech/node_modules/.pnpm/next@16.0.10_@opentelemetry+api@1.9.0_react-dom@19.2.0_react@19.2.0__react@19.2.0/node_modules/next/dist/export/worker.d.ts
3 /root/Zapflix-Tech/node_modules/.pnpm/next@16.0.10_@opentelemetry+api@1.9.0_react-dom@19.2.0_react@19.2.0__react@19.2.0/node_modules/next/dist/build/worker.d.ts
1 /root/Zapflix-Tech/node_modules/.pnpm/vitest@4.0.18_@edge-runtime+vm@5.0.0_@opentelemetry+api@1.9.0_@types+node@22.19.8_@vite_f024dae4ff490031200e5d7798eb96cc/node_modules/vitest/worker.d.ts
32 /root/Zapflix-Tech/node_modules/.pnpm/vitest@4.0.18_@edge-runtime+vm@5.0.0_@opentelemetry+api@1.9.0_@types+node@22.19.8_@vite_f024dae4ff490031200e5d7798eb96cc/node_modules/vitest/dist/worker.d.ts
1 /root/Zapflix-Tech/node_modules/.pnpm/next@16.0.10_@opentelemetry+api@1.9.0_react-dom@19.2.0_react@19.2.0__react@19.2.0/node_modules/next/dist/server/lib/worker-utils.d.ts
255 /root/Zapflix-Tech/node_modules/.pnpm/vitest@4.0.18_@edge-runtime+vm@5.0.0_@opentelemetry+api@1.9.0_@types+node@22.19.8_@vite_f024dae4ff490031200e5d7798eb96cc/node_modules/vitest/dist/chunks/worker.d.Dyxm8DEL.d.ts
286 /root/Zapflix-Tech/node_modules/.pnpm/bullmq@5.69.3/node_modules/bullmq/dist/esm/classes/worker.d.ts
143 /root/Zapflix-Tech/node_modules/.pnpm/bullmq@5.69.3/node_modules/bullmq/dist/esm/interfaces/worker-options.d.ts
715 /root/Zapflix-Tech/node_modules/.pnpm/@types+node@20.19.31/node_modules/@types/node/worker_threads.d.ts
715 /root/Zapflix-Tech/node_modules/@wdio/types/node_modules/@types/node/worker_threads.d.ts
715 /root/Zapflix-Tech/node_modules/@wdio/repl/node_modules/@types/node/worker_threads.d.ts
