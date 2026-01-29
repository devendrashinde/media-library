export const environment = {
  production: false,
  apiUrl: (() => {
    // Use proxy in development (ng serve uses port 4200, backend on 3000)
    if (typeof window !== 'undefined' && window.location.hostname === 'localhost') {
      return '/api';
    }
    // In production, use the backend API URL based on current host
    if (typeof window !== 'undefined') {
      const host = window.location.hostname;
      const port = 3000;
      return `http://${host}:${port}`;
    }
    return '/api';
  })()
};