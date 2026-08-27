import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { FixedCommitmentsController } from '../controllers/commitments.controller';

const router = Router();

router.use(authenticate);

router.post('/', FixedCommitmentsController.create);
router.get('/', FixedCommitmentsController.list);
router.get('/:id', FixedCommitmentsController.get);
router.patch('/:id', FixedCommitmentsController.update);
router.delete('/:id', FixedCommitmentsController.delete);

export default router;
