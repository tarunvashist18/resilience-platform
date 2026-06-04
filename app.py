from flask import Flask, render_template, request, jsonify, redirect, url_for
from services.deployer import deploy_image, wait_for_pods, cleanup_deployment
from services.chaos_runner import run_all_chaos_tests
from services.scorer import calculate_scores
import threading
import uuid
import time

app = Flask(__name__)

# In-memory job store
jobs = {}

def run_test_job(job_id, docker_image):
    jobs[job_id]['status'] = 'deploying'
    jobs[job_id]['message'] = 'Deploying image to Kubernetes...'

    success, result = deploy_image(docker_image)

    if not success:
        jobs[job_id]['status'] = 'error'
        jobs[job_id]['message'] = f'Deployment failed: {result}'
        return

    safe_name = result
    jobs[job_id]['status'] = 'waiting'
    jobs[job_id]['message'] = 'Waiting for pods to become ready...'

    pods_ready = wait_for_pods(safe_name)

    if not pods_ready:
        jobs[job_id]['status'] = 'error'
        jobs[job_id]['message'] = 'Pods did not become ready in time.'
        return

    chaos_tests = [
        'Pod Chaos Test',
        'CPU Stress Test',
        'Memory Stress Test',
        'Network Delay Test',
        'Packet Loss Test',
        'Recovery Validation',
    ]

    for i, test_name in enumerate(chaos_tests):
        jobs[job_id]['status'] = 'testing'
        jobs[job_id]['message'] = f'Running {test_name}... ({i+1}/6)'
        time.sleep(1)

    test_results = run_all_chaos_tests(safe_name)
    scores = calculate_scores(test_results)

    # Cleanup
    cleanup_deployment(safe_name)

    jobs[job_id]['status'] = 'done'
    jobs[job_id]['message'] = 'Testing complete!'
    jobs[job_id]['test_results'] = test_results
    jobs[job_id]['scores'] = scores
    jobs[job_id]['docker_image'] = docker_image


@app.route('/')
def index():
    return render_template('index.html')


@app.route('/run-test', methods=['POST'])
def run_test():
    docker_image = request.form.get('docker_image')
    job_id = str(uuid.uuid4())

    jobs[job_id] = {
        'status': 'starting',
        'message': 'Starting test...',
        'docker_image': docker_image,
        'test_results': None,
        'scores': None,
    }

    thread = threading.Thread(target=run_test_job, args=(job_id, docker_image))
    thread.daemon = True
    thread.start()

    return redirect(url_for('loading', job_id=job_id))


@app.route('/loading/<job_id>')
def loading(job_id):
    job = jobs.get(job_id)
    if not job:
        return redirect(url_for('index'))
    return render_template('loading.html',
                           job_id=job_id,
                           docker_image=job['docker_image'])


@app.route('/status/<job_id>')
def status(job_id):
    job = jobs.get(job_id)
    if not job:
        return jsonify({'status': 'not_found'})
    return jsonify({
        'status': job['status'],
        'message': job['message'],
    })


@app.route('/result/<job_id>')
def result(job_id):
    job = jobs.get(job_id)
    if not job or job['status'] != 'done':
        return redirect(url_for('loading', job_id=job_id))
    return render_template('result.html',
                           docker_image=job['docker_image'],
                           deploy_error=None,
                           deployed=True,
                           pods_ready=True,
                           test_results=job['test_results'],
                           scores=job['scores'])


if __name__ == '__main__':
    app.run(debug=False, port=5001)
