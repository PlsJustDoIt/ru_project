import { serve, setup } from 'swagger-ui-express';
import YAML from 'yaml';
import { readFileSync } from 'fs';
import { join } from 'path';
import { rootDir } from '../config.js';
import { Express } from 'express';

const swaggerSetup = (app: Express) => {
    const swaggerFilePath = join(rootDir, 'swagger.yaml');
    const file = readFileSync(swaggerFilePath, 'utf8');
    const swaggerDocument = YAML.parse(file);

    app.use('/api-docs', serve, setup(swaggerDocument));
};

export default swaggerSetup;
