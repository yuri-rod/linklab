import json
import logging
import os
import signal
import sys
import time
from datetime import datetime, timezone

import psycopg2
import redis

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    stream=sys.stdout,
)
logger = logging.getLogger(__name__)

REDIS_URL = os.environ.get("REDIS_URL")
DATABASE_URL = os.environ.get("DATABASE_URL")

if not REDIS_URL or not DATABASE_URL:
    logger.error("REDIS_URL e DATABASE_URL são obrigatórios")
    sys.exit(1)

r = redis.from_url(REDIS_URL)
conn = psycopg2.connect(DATABASE_URL)
conn.autocommit = False

stop = False

def handle_exit(signum, frame):
    global stop
    stop = True
    logger.info("Encerrando worker...")

signal.signal(signal.SIGINT, handle_exit)
signal.signal(signal.SIGTERM, handle_exit)

logger.info("Worker iniciado. Aguardando eventos na lista 'clicks'...")

while not stop:
    try:
        result = r.brpop("clicks", timeout=5)
        if result:
            _, code = result
            code = code.decode()
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO clicks (code, clicked_at) VALUES (%s, %s)",
                    (code, datetime.now(timezone.utc)),
                )
            conn.commit()
            logger.info("Click registrado: %s", code)
    except psycopg2.Error as e:
        logger.error("Erro no banco: %s", e)
        conn.rollback()
        time.sleep(1)
    except redis.RedisError as e:
        logger.error("Erro no Redis: %s", e)
        time.sleep(1)
    except Exception as e:
        logger.exception("Erro inesperado: %s", e)
        time.sleep(1)

conn.close()
logger.info("Worker finalizado")
