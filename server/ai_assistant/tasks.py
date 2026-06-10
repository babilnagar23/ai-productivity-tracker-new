from celery import shared_task

from .models import AiJob
from common.groq_client import generate_ai_response


@shared_task(bind=True, max_retries=3)
def process_ai_job(self, job_id):
    try:
        job = AiJob.objects.get(id=job_id)

        job.status = 'processing'
        job.save(update_fields=['status'])

        result = generate_ai_response(job.prompt)

        job.result = result
        job.status = 'done'
        job.save(
            update_fields=[
                'result',
                'status',
            ]
        )

    except Exception as e:
        try:
            self.retry(
                countdown=5,
                exc=e,
            )
        except self.MaxRetriesExceededError:
            job.status = 'failed'
            job.error = str(e)
            job.save(
                update_fields=[
                    'status',
                    'error',
                ]
            )