export const environment = {
  production: true,
  apiUrl: (() => {
    // In production, use the backend API URL based on current host
    if (typeof window !== 'undefined') {
      const host = window.location.hostname;
      const port = 3000;
      return `http://${host}:${port}`;
    }
    return 'http://localhost:3000';
  })()
};
