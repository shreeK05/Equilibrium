import { app } from './app';
import { config } from './config';

app.listen(config.port, () => {
  console.log(`Equilibrium backend running on port ${config.port}`);
});
