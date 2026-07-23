import logging

from celery import shared_task

from .models import AiJob
from common.groq_client import generate_ai_response

logger = logging.getLogger('celery.tasks')


@shared_task(bind=True, max_retries=3)
def process_ai_job(self, job_id):
    """
    Process an async AI job.

    Initialise ``job`` to ``None`` before the try block so that the
    MaxRetriesExceededError handler can safely check whether the DB
    record was ever retrieved before attempting to update it.
    """
    job = None  # Prevent reference-before-assignment in the exception handler

    try:
        job = AiJob.objects.get(id=job_id)

        job.status = 'processing'
        job.save(update_fields=['status'])

        logger.info('[AI Task] job_id=%s — processing started', job_id)

        result = generate_ai_response(job.prompt, clean=True)

        job.result = result
        job.status = 'done'
        job.save(update_fields=['result', 'status'])

        logger.info('[AI Task] job_id=%s — completed successfully', job_id)

    except AiJob.DoesNotExist:
        logger.error('[AI Task] job_id=%s not found — cannot process', job_id)
        # Nothing to update; do not retry a non-existent job.

    except Exception as exc:
        logger.warning('[AI Task] job_id=%s — attempt %d failed: %s', job_id, self.request.retries + 1, exc)
        try:
            # Exponential back-off: 5s, 25s, 125s
            self.retry(countdown=5 ** (self.request.retries + 1), exc=exc)
        except self.MaxRetriesExceededError:
            logger.error('[AI Task] job_id=%s — all retries exhausted: %s', job_id, exc)
            if job is not None:
                job.status = 'failed'
                job.error = str(exc)
                job.save(update_fields=['status', 'error'])
            else:
                logger.error(
                    '[AI Task] job_id=%s — MaxRetriesExceeded but job record was never loaded; '
                    'status cannot be persisted.',
                    job_id,
                )