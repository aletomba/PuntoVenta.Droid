import { createServer } from 'node:http';

const host = process.env.MOCK_HOST ?? '127.0.0.1';
const port = Number(process.env.MOCK_PORT ?? 4010);
const productId = 'b176f70d-b1f8-4f01-b99b-5b2677c67952';
const saleId = 'f81d7795-31f8-44fa-9f54-1f2e31a42d07';
const now = new Date().toISOString();

const product = {
  id: productId,
  barcode: '7790001000010',
  name: 'Producto de ejemplo',
  priceCents: 125000,
  stock: 12,
  updatedAt: now,
  isDeleted: false,
};

const sale = {
  id: saleId,
  paymentMethod: 'cash',
  items: [
    {
      id: 'ca266f14-b722-4e0a-8244-ddc66cdcaaf0',
      productId,
      description: product.name,
      quantity: 1,
      unitPriceCents: product.priceCents,
    },
  ],
  totalCents: product.priceCents,
  status: 'active',
  date: now,
  voidedAt: null,
  voidedByUserId: null,
  voidReason: null,
};

function respond(response, status, payload) {
  response.writeHead(status, { 'content-type': 'application/json; charset=utf-8' });
  response.end(payload === undefined ? '' : JSON.stringify(payload));
}

const server = createServer((request, response) => {
  const url = new URL(request.url ?? '/', `http://${request.headers.host ?? 'localhost'}`);
  const { method } = request;

  if (method === 'POST' && url.pathname === '/auth/login') {
    respond(response, 200, {
      accessToken: 'mock-access-token',
      refreshToken: 'mock-refresh-token',
      expiresAt: new Date(Date.now() + 15 * 60_000).toISOString(),
    });
    return;
  }

  if (method === 'POST' && url.pathname === '/auth/refresh') {
    respond(response, 200, {
      accessToken: 'mock-access-token',
      refreshToken: 'mock-refresh-token',
      expiresAt: new Date(Date.now() + 15 * 60_000).toISOString(),
    });
    return;
  }

  if (method === 'GET' && url.pathname === '/products') {
    respond(response, 200, [product]);
    return;
  }

  if (method === 'POST' && url.pathname === '/products') {
    respond(response, 201, product);
    return;
  }

  if (url.pathname === `/products/${productId}` && method === 'PUT') {
    respond(response, 200, product);
    return;
  }

  if (url.pathname.startsWith('/products/') && method === 'DELETE') {
    respond(response, 204);
    return;
  }

  if (method === 'GET' && url.pathname === '/sales') {
    respond(response, 200, [sale]);
    return;
  }

  if (method === 'POST' && url.pathname === '/sales') {
    respond(response, 201, sale);
    return;
  }

  if (url.pathname === `/sales/${saleId}/void` && method === 'POST') {
    respond(response, 200, { ...sale, status: 'voided', voidedAt: now });
    return;
  }

  if (method === 'GET' && url.pathname === '/cash-close') {
    respond(response, 200, {
      day: url.searchParams.get('day') ?? now.slice(0, 10),
      totalCents: sale.totalCents,
      byPaymentMethod: { cash: sale.totalCents },
    });
    return;
  }

  if (method === 'POST' && url.pathname === '/sync/push') {
    respond(response, 200, {
      acceptedIds: [productId, saleId],
      rejected: [],
    });
    return;
  }

  if (method === 'GET' && url.pathname === '/sync/pull') {
    respond(response, 200, { products: [product], nextSince: now });
    return;
  }

  respond(response, 404, { code: 'not_found', message: 'Mock route not found.' });
});

server.listen(port, host, () => {
  console.log(`OpenAPI mock listening on http://${host}:${port}`);
});
