import { Request, Response, NextFunction } from 'express';
import { validationResult } from 'express-validator';

export const validate = (req: Request, res: Response, next: NextFunction): any => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    const array = errors.array();
    return res.status(400).json({
      success: false,
      message: array[0].msg,
      errors: array.map((err: any) => ({
        field: err.path,
        message: err.msg,
      })),
    });
  }
  next();
};
